module main

import flag
import log
import os
import veb

pub struct Context {
	veb.Context
}

@[xdoc: 'A web URL-shortener, written in V']
@[name: 'VURLS']
@[version: '0.0.0']
struct AppConfig {
	config_file_path   string @[long: config; short: c; skip; xdoc: 'Load or create config at given path']
	ignore_config_file bool   @[long: ignorecfg; short: i; skip; xdoc: 'Dont load any config files']
	port               int    = 8080    @[short: p; xdoc: 'Specify port to listen on (default 8080)']
	db_path            string = ':memory:' @[short: d; xdoc: 'Path to the SQLite3 DB to use (default memory)']
	password           string @[short: P; xdoc: 'Optional password to require to shorten an URL']
	admin_password     string @[long: admpwd; short: a; xdoc: 'Optional admin password for administrative purposes (undefined = disabled)']
	expiration_time    i64 = 60 * 60 * 24    @[short: e; xdoc: 'Time in seconds the short URL expires after creation (default 24 hours)']
	shortening_timeout i64 = 60 * 5    @[short: t; xdoc: 'Time in seconds after an IP-address can shorten another URL (default 5 minutes)']
	verbose            bool   @[short: v; xdoc: 'Log shortenings and redirects']
	show_help          bool   @[long: help; short: h; skip]
}

struct App {
mut:
	db                         ShortenerDB
	config                     AppConfig
	shortening_timeout_tracker map[string]i64 = {}
}

fn main() {
	mut cfg, _ := flag.to_struct[AppConfig](os.args) or { panic(err) }
	if cfg.show_help {
		documentation := flag.to_doc[AppConfig]()!
		println(documentation)
		exit(0)
	}

	if !cfg.ignore_config_file {
		cfg = load_config_file(cfg)
	}

	mut l := log.Log{}
	l.set_level(if cfg.verbose { .info } else { .warn })
	l.set_time_format(.tf_ss)
	log.set_logger(l)
	println('Using log level: ${log.get_level()}')

	mut app := &App{}
	app.config = cfg
	app.db = ShortenerDB.connect(cfg) or { panic(err) }

	veb.run[App, Context](mut app, app.config.port)
}
