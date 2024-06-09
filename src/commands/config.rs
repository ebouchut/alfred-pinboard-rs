use super::{process, Config, SubCommand};
use alfred::ItemBuilder;
use chrono::prelude::Local;

pub fn run(x: SubCommand) {
    debug!("Starting in run");
    let print_config;
    let mut config: Config;

    match x {
        SubCommand::Config {
            display,
            auth_token,
            number_pins,
            number_tags,
            shared,
            toread,
            fuzzy,
            tags_only,
            auto_update,
            suggest_tags,
            check_bookmarked_page,
            show_url_vs_tags,
        } => {
            print_config = display;
            let mut token = String::new();
            if let Some(atoken) = &auth_token {
                if atoken.find(':').is_some() {
                    token.clone_from(atoken);
                } else {
                    crate::show_error_alfred("Invalid Auth Token format!".to_string());
                    process::exit(1);
                }
            }
            config = Config::setup().unwrap_or_else(|err| {
                info!("{}", err.to_string());
                let mut config = Config::new();
                if auth_token.is_some() {
                    config.auth_token = token;
                } else {
                    crate::show_error_alfred(err.to_string());
                    process::exit(1);
                }
                config
            });
            debug!("{:?}", config);
            config.auth_token.update(auth_token);
            config.pins_to_show.update(number_pins);
            config.tags_to_show.update(number_tags);
            // config.private_new_pin.update(!shared);
            config.private_new_pin = !shared.unwrap_or(!config.private_new_pin);
            config.toread_new_pin.update(toread);
            config.fuzzy_search.update(fuzzy);
            config.tag_only_search.update(tags_only);
            config.auto_update_cache.update(auto_update);
            config.suggest_tags.update(suggest_tags);
            config.page_is_bookmarked.update(check_bookmarked_page);
            config.show_url_vs_tags.update(show_url_vs_tags);
        }
        _ => unreachable!(),
    }

    if let Err(e) = config.save() {
        error!("Couldn't save config file: {:?}", e);
    } else {
        debug!(
            "Saved new configs to {} in: {}",
            crate::workflow_config::CONFIG_FILE_NAME,
            config.data_dir().to_string_lossy()
        );
    }

    if print_config {
        show_config(&config);
    }
}

fn show_config(config: &Config) {
    debug!("Starting in show_config");
    let items = vec![
        ItemBuilder::new("Only search tags")
            .subtitle(format!("{:?}", config.tag_only_search))
            .arg("pset tagonly")
            .icon_path("tagonly.png")
            .into_item(),
        ItemBuilder::new("Use fuzzy search")
            .subtitle(format!("{:?}", config.fuzzy_search))
            .arg("pset fuzzy")
            .icon_path("fuzzy.png")
            .into_item(),
        ItemBuilder::new("Automatically update cache")
            .subtitle(format!("{:?}", config.auto_update_cache))
            .arg("pset auto")
            .icon_path("auto_update_cache.png")
            .into_item(),
        ItemBuilder::new("Suggest popular tags for open browser tab")
            .subtitle(format!("{:?}", config.suggest_tags))
            .arg("pset suggest_tags")
            .icon_path("suggest.png")
            .into_item(),
        ItemBuilder::new("Mark new bookmarks as toread")
            .subtitle(format!("{:?}", config.toread_new_pin))
            .arg("pset toread")
            .icon_path("toread.png")
            .into_item(),
        ItemBuilder::new("Mark new bookmarks as private")
            .subtitle(format!("{:?}", config.private_new_pin))
            .arg("pset shared")
            .icon_path("private.png")
            .into_item(),
        ItemBuilder::new("Check if page is bookmarked")
            .subtitle(format!("{:?}", config.page_is_bookmarked))
            .arg("pset check_bookmarked")
            .icon_path("check_bookmarked_page.png")
            .into_item(),
        ItemBuilder::new("Show TAGs vs URLs in search results")
            .subtitle(format!("{:?}", config.show_url_vs_tags))
            .arg("pset url_tag")
            .icon_path("url.png")
            .into_item(),
        ItemBuilder::new("Number of tags to show")
            .subtitle(format!("{:?}", config.tags_to_show))
            .arg("pset tags")
            .icon_path("no_of_tags.png")
            .into_item(),
        ItemBuilder::new("Number of bookmarks to show")
            .subtitle(format!("{:?}", config.pins_to_show))
            .arg("pset bookmarks")
            .icon_path("no_of_pins.png")
            .into_item(),
        ItemBuilder::new("Click to check for Workflow updates.")
            .arg("pcheck")
            .icon_path("check_update.png")
            .into_item(),
        ItemBuilder::new(
            config
                .update_time
                .with_timezone(&Local)
                .format("%Y-%m-%d %H:%M:%S")
                .to_string(),
        )
        .subtitle("Latest cache update")
        .arg("pupdate")
        .icon_path("auto_update.png")
        .into_item(),
    ];
    let none: Option<Vec<(&str, &str)>> = None;
    crate::write_to_alfred(items, config.can_use_json(), none);
}

/// Trait to update a value optionally based on `opt`
trait OptionalUpdate: Sized {
    fn update(&mut self, opt: Option<Self>) {
        if let Some(val) = opt {
            *self = val;
        }
    }
}

impl<T> OptionalUpdate for T {}
