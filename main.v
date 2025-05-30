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
}

@["/:path..."]
pub fn (app &App) root(mut ctx Context, _path string) veb.Result {
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
	css := $tmpl("templates/style.css")
	return ctx.text(css)
}

pub fn (app &App) script(mut ctx Context) veb.Result {
	ctx.set_content_type("text/javascript")
	js := $tmpl("templates/script.js")
	return ctx.text(js)
}

@[post]
pub fn (app &App) shorten(mut ctx Context) veb.Result {
	password := ctx.form["password"]

	if password != app.password {
		return ctx.request_error("Wrong Password!")
	}

	url := ctx.form["url"]

	if !url_valid(url) {
		return ctx.request_error("Invalid URL!")
	}

	mut s := ShortUrl{}
	s.url = url
	s.ip_address = ctx.ip()
	now := time.now().unix()
	s.created = now
	s.expires = now + app.expiration_time

	id := sql app.db {
		insert s into ShortUrl
	} or {
		println("shorten: failed to insert into DB: ${err}")
		return ctx.server_error("Unknown server failure!")
	}

	path := base58.encode_int(id) or { panic(err) }

	return ctx.ok(path)
}

fn main() {
	mut app := &App{}
	app.db = ShortenerDB.new() or { panic(err) }

    veb.run[App, Context](mut app, app.port)
}
