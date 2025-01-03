# This Project Is Unsupported

I have no plans to push another update. I tried years back but never
had the bandwidth to figure out all of the changes required to make it
compatible with the increased variety of iOS screen sizes.

In the meantime, KeePass 1's file format is deprecated and there are
better Dropbox-synced KeePass apps.

----

# passdrop

*This is a modern, updated build of [Rudis Muiznieks](https://github.com/rudism)'s PassDrop application.*

PassDrop is a fully-featured secure password management system, compatible with the free [KeePass 1.x (Classic)](http://keepass.info/) and multi-platform [KeePassX](http://www.keepassx.org/) desktop applications. PassDrop uses the free [Dropbox](http://www.dropbox.com) storage service for hassle-free synchronization of your password databases between your iPhone, Windows, macOS, and Linux computers.

The current version 2.0 is available on the [iOS App Store](https://itunes.apple.com/us/app/passdrop-2/id1206056096).

## PassDrop FAQ

If you are experiencing issues or need help using PassDrop, please check out the [PassDrop FAQ](https://github.com/rudism/passdrop/blob/master/FAQ.md).

## Current Features (2.0)

- Strong emphasis on clean, simple, intuitive user interface
- Load, create, and edit multiple KeePass 1.x databases in your Dropbox account
- Open KeePass 1.x databases with any file extension
- Fully integrated two-way syncing to Dropbox, with collision detection
- Lock file utilization when opening databases in edit mode
- Offline read access to databases when no network is available
- View, create, move, sort, and edit all groups and entries nested to any level
- Password generator to automatically create random strong passwords for entries
- Entry search capabilities at global and group-specific levels
- Copy logins, passwords, URLs, or notes to your clipboard
- Automatically open URLs in Safari while PassDrop remains open in the background
- Optionally clear clipboard whenever PassDrop is re-activated
- "Lock in background" option to auto-lock your database after a customizable amount of time
- Hide "Backup" group results when searching entries
- Encrypted HTTPS communication directly with the official Dropbox API for maximum security

## Commonly Requested Missing Features

- File attachment viewing and sharing
- Option to visually mark or hide expired entries
- Add files from other apps via file sharing
- Ability to unlink Dropbox and keep local databases
- Key file authentication
- Better UTF16/international character support
- KeePass 2.x database support
- KeePass 2.x is not an improved version of KeePass 1.x, but rather an entirely new product with completely unrelated file formats. Both KeePass 1.x and 2.x are actively developed and maintained and are viable password storage solutions. I chose to support KeePass 1.x with PassDrop due to the higher portability and multi-platform support for the KeePass 1.x file format.
- Twofish encryption
