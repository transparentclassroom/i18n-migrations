# I18n Migrations

We help you manage your locale translations with migrations, just the way Active Record helps you manage your db with migrations.

There are several tools out there that allow you to dynamically store / load / translate strings in your app. We prefer to deploy our app with static files using the excellent i18n gem. But how to translate?

Our flow is:

1. Use a migration to make a change (add/remove/update/move) to your translations locally. In this state, we will use google translate to quickly guess at translations.
1. When ready to deploy, push these changes to google spreadsheets, one for each translation, there, your translators can fix google translate's mistakes.
1. Pull to replace your translations with what's in those google spreadsheets.
1. Migrate to play back any changes after pulling / merging / etc.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'i18n-migrations'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install i18n-migrations
    
From your project file, you'll want to run 

    $ i18n-migrate setup
    
This will create a config file you can edit.

## Usage

Let's imagine that your config file look like this:

    migration_dir: i18n/migrate
    locales_dir: config/locales
    main_locale: en
    other_locales:
    - es
    ..

In your project file, you should then have all your english terms in ```config/locales/en.yml```

You can:

* [Create a new locale](https://github.com/transparentclassroom/i18n-migrations/wiki/Create-a-new-locale-(language))
* [Add a migration](https://github.com/transparentclassroom/i18n-migrations/wiki/Add-a-migration)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/i18n-migrations/fork )
1. Create your feature branch (`git checkout -b my-new-feature`)
1. Make sure tests are passing (`rake`)
1. Commit your changes (`git commit -am 'Add some feature'`)
1. Push to the branch (`git push origin my-new-feature`)
1. Create a new Pull Request

