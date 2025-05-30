module main

import db.sqlite
import json

type ShortenerDB = sqlite.DB

fn ShortenerDB.new() !ShortenerDB {
	db := sqlite.connect(":memory:")!
	db.journal_mode(sqlite.JournalMode.memory)!

	sql db {
		create table ShortUrl
	}!

	return db
}

fn (db ShortenerDB) dump() !string {
	rows := sql db {
		select from ShortUrl
	}!

	return json.encode(rows)
}