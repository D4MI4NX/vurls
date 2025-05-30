module main

import regex

@[table: 'short_urls']
struct ShortUrl {
	id u64 @[primary; serial]
mut:
	expires i64
	url string
	ip_address string
	created i64
}

fn url_valid(url string) bool {
	exp := regex.regex_opt(r"^([a-zA-Z0-9+\-.])*:(?://)?(.)*$") or { panic(err) }
	start, _ := exp.match_string(url)
	return start != -1
}