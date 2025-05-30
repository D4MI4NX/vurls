module main

import db.sqlite

type ShortenerDB = sqlite.DB

fn ShortenerDB.new() !ShortenerDB {
	db := sqlite.connect(":memory:")!
	db.journal_mode(sqlite.JournalMode.memory)!

	sql db {
		create table ShortUrl
	}!

	return db
}