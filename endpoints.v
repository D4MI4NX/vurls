module main

import encoding.base58
import log
import time
import veb

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
			"dump_db" { return app.dump_db(mut ctx) }
			else {}
		}
	}

	id := base58.decode_int(path) or {
		return ctx.request_error("Invalid redirect path")
	}

	result := sql app.db {
		select from ShortUrl where id == id
	} or {
		log.error("root: failed to get entry from DB: ${err}")
		return ctx.server_error("Unknown server failure")
	}

	if result.len == 0 {
		return ctx.request_error("Redirect not found")
	}

	s := result.first()

	log.info("[>] ${ctx.ip()} -> ${s.url}")

	return ctx.redirect(s.url)
}

pub fn (app &App) index(mut ctx Context) veb.Result {
    hidden_value := if app.config.password != "" {""} else {"hidden"}
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

	if password != app.config.password {
		return ctx.request_error("Wrong Password!")
	}

	url := ctx.form["url"]

	if !url_valid(url) {
		return ctx.request_error("Invalid URL!")
	}

	rows := sql app.db {
		select from ShortUrl where url == url
	} or {
		log.error("shorten: failed query DB: ${err}")
		return ctx.server_error("Unknown server failure!")
	}

	mut id := i64(0)

	if 0 < rows.len {
		id = rows.first().id
	} else {
		expired_rows := sql app.db {
			select from ShortUrl where expires < now
		} or {
			log.error("shorten: failed to query DB: ${err}")
			[]ShortUrl{}
		}

		mut s := ShortUrl{}
		s.url = url
		s.ip_address = ip
		s.created = now
		s.expires = now + app.config.expiration_time

		if 0 < expired_rows.len {
			row := expired_rows.first()
			sql app.db {
				update ShortUrl set
					expires = s.expires
					,url = s.url
					,ip_address = s.ip_address
					,created = s.created
				where id == row.id
			} or {
				log.error("shorten: failed to update DB: ${err}")
				return ctx.server_error("Unknown server failure!")
			}
			id = row.id
		} else {
			id = sql app.db {
				insert s into ShortUrl
			} or {
				log.error("shorten: failed to insert into DB: ${err}")
				return ctx.server_error("Unknown server failure!")
			}
		}

		app.shortening_timeout_tracker[ip] = now + app.config.shortening_timeout
	}

	path := base58.encode_int(int(id)) or {
		log.error("failed to base58 encode ${id}: ${err}")
		return ctx.server_error("Unknown server failure!")
	}

	log.info("[+] ${ip} -> ${url} = ${path}")

	return ctx.ok(path)
}

@[post]
pub fn (app &App) dump_db(mut ctx Context) veb.Result {
	password := ctx.form["password"]
	ip := ctx.ip()

	if app.config.admin_password == "" || app.config.admin_password != password {
		log.warn("[!] ${ip} tried admin password <${password}>")
		return ctx.request_error("Permission denied!")
	}

	log.warn("[?] ${ip} authenticated as admin")

	db_dump := app.db.dump() or {
		log.error("dump_db: ${err}")
		return ctx.server_error(err.str())
	}

	ctx.set_content_type("application/json")
	return ctx.text(db_dump)
}