module main

import veb

pub struct Context {
    veb.Context
pub mut:
    password string
	ip_address string
}

struct App {
mut:
    password string // optional password to create a short URL
	expiration_time i64 = 60*60*24 // 24 hours
}

@["/index.html"]
pub fn (app &App) index(mut ctx Context) veb.Result {
    hidden_value := if app.password != "" {""} else {'hidden="hidden"'}
	idx := $tmpl("templates/index.html")
	return ctx.html(idx)
}

@["/style.css"]
pub fn (app &App) style(mut ctx Context) veb.Result {
	ctx.set_content_type("text/css")
	css := $tmpl("templates/style.css")
	return ctx.text(css)
}

fn main() {
	db := ShortenerDB.new()or { panic(err) }

	mut app := &App{}

    veb.run[App, Context](mut app, 8080)
}
