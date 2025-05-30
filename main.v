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
	db ShortenerDB
	port u16 = 8080
    password string // optional password to create a short URL
	expiration_time i64 = 60*60*24 // 24 hours
	shortening_timeout i64 = 60*5 // 5 Minutes
	shortening_timeout_tracker map[string]i64 = {}
}

fn main() {
	mut app := &App{}
	app.db = ShortenerDB.new() or { panic(err) }

    veb.run[App, Context](mut app, app.port)
}
