module main

import encoding.base58
import time
import veb

pub struct Context {
    veb.Context
pub mut:
    password string
	ip_address string
}

struct App {
mut:
	db ShortenerDB
	port u16 = 8080
    password string // optional password to create a short URL
	expiration_time i64 = 60*60*24 // 24 hours
	shortening_timeout i64 = 60*5 // 5 Minutes
	shortening_timeout_tracker map[string]i64 = {}
}

@["/:path..."]
pub fn (mut app App) root(mut ctx Context, _path string) veb.Result {
	path := _path.trim_left("/")

	match path {
		"index.html", "" { return app.index(mut ctx) }
		"style.css" { return app.style(mut ctx) }
		"script.js" { return app.script(mut ctx) }
		else {}
	}

	if ctx.req.method == .post {
		match path {
			"shorten" { return app.shorten(mut ctx) }
			else {}
		}
	}

	id := base58.decode_int(path) or {
		return ctx.request_error("Invalid redirect path")
	}

	result := sql app.db {
		select from ShortUrl where id == id
	} or {
		println("root: failed to get entry from DB: ${err}")
		return ctx.server_error("Unknown server failure")
	}

	if result.len == 0 {
		return ctx.request_error("Redirect not found")
	}

	s := result.first()

	return ctx.redirect(s.url)
}

pub fn (app &App) index(mut ctx Context) veb.Result {
    hidden_value := if app.password != "" {""} else {"hidden"}
	idx := $tmpl("templates/index.html")
	return ctx.html(idx)
}

pub fn (app &App) style(mut ctx Context) veb.Result {
	ctx.set_content_type("text/css")
	css := $embed_file("templates/style.css", .zlib)
	return ctx.text(css.to_string())
}

pub fn (app &App) script(mut ctx Context) veb.Result {
	ctx.set_content_type("text/javascript")
	js := $embed_file("templates/script.js", .zlib)
	return ctx.text(js.to_string())
}

@[post]
pub fn (mut app App) shorten(mut ctx Context) veb.Result {
	ip := ctx.ip()
	now := time.now().unix()

	timeout := app.shortening_timeout_tracker[ip] - now
	if 0 < timeout {
		return ctx.request_error("Shortening timeout. ${timeout}s remaining")
	} else {
		app.shortening_timeout_tracker.delete(ip)
	}

	password := ctx.form["password"]

	if password != app.password {
		return ctx.request_error("Wrong Password!")
	}

	url := ctx.form["url"]

	if !url_valid(url) {
		return ctx.request_error("Invalid URL!")
	}

	rows := sql app.db {
		select from ShortUrl where url == url
	} or {
		println("shorten: failed query DB: ${err}")
		return ctx.server_error("Unknown server failure!")
	}

	mut id := i64(0)

	if 0 < rows.len {
		id = rows.first().id
	} else {
		mut s := ShortUrl{}
		s.url = url
		s.ip_address = ip
		s.created = now
		s.expires = now + app.expiration_time

		id = sql app.db {
			insert s into ShortUrl
		} or {
			println("shorten: failed to insert into DB: ${err}")
			return ctx.server_error("Unknown server failure!")
		}

		app.shortening_timeout_tracker[ip] = now + app.shortening_timeout
	}

	path := base58.encode_int(int(id)) or { panic(err) }

	return ctx.ok(path)
}

fn main() {
	mut app := &App{}
	app.db = ShortenerDB.new() or { panic(err) }

    veb.run[App, Context](mut app, app.port)
}
