module main

import os
import toml

fn get_config_paths() []string {
	user_cfg_dir := os.config_dir() or {
		println("Could not get user config dir: ${err}")
		""
	}

	filename := "vurls.toml"

	mut config_paths := []string{}

	config_paths << filename

	if user_cfg_dir != "" {
		config_paths << os.join_path_single(user_cfg_dir, filename)
	}

	match os.user_os() {
		"linux", "freebsd", "openbsd", "darwin" {
			config_paths << os.join_path_single("/etc", filename)
		}
		"windows" {
			config_paths << os.join_path_single(r"C:\ProgramData", filename)
		}
		else {}
	}

	return config_paths
}

fn load_config_file(cfg AppConfig) AppConfig {
	mut config_paths := []string{}

	if cfg.config_file_path == "" {
		config_paths = get_config_paths()
	} else {
		config_paths = [cfg.config_file_path]
	}

	for path in config_paths {
		if !os.exists(path) {
			if cfg.config_file_path != "" {
				content := toml.encode(cfg)
				os.write_file(path, content) or {
					println("Could not write config at ${path}: ${err}")
					break
				}
				println("Config file created at ${path}")
				break
			}
			continue
		}

		doc := toml.parse_file(path) or {
			println("Failed to load config ${path}: ${err}")
			continue
		}

		new_cfg := doc.decode[AppConfig]() or {
			println("Failed to decode config ${path}: ${err}")
			continue
		}

		println("Loaded config ${path}")

		return new_cfg
	}

	return cfg
}