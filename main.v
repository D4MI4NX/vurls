module main

import flag
import os
import veb

pub struct Context {
    veb.Context
}

@[xdoc: "A web URL-shortener, written in V"]
@[version: "0.0.0"]
@[name: "VURLS"]
struct AppConfig {
	port u16 = 8080 @[short: p; xdoc: "Specify port to listen on (default 8080)"]
	password string @[short: P; xdoc: "Optional password to require to shorten an URL"] // optional password to create a short URL
	expiration_time i64 = 60*60*24 @[short: e; xdoc: "Time in seconds the short URL expires after creation (default 24 hours)"] // 24 hours
	shortening_timeout i64 = 60*5 @[short: t; xdoc: "Time in seconds after an IP-address can shorten another URL (default 5 minutes)"] // 5 minutes
	show_help bool @[short: h; long: help]
}

struct App {
mut:
	db ShortenerDB
	config AppConfig
	shortening_timeout_tracker map[string]i64 = {}
}

fn main() {
	cfg, _ := flag.to_struct[AppConfig](os.args) or { panic(err) }
	if cfg.show_help {
        documentation := flag.to_doc[AppConfig]()!
        println(documentation)
        exit(0)
    }

	mut app := &App{}
	app.config = cfg
	app.db = ShortenerDB.new() or { panic(err) }

    veb.run[App, Context](mut app, app.config.port)
}
