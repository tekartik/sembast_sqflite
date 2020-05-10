# sembast_sqflite

sembast DB for flutter on top of sqflite.

* Supports both iOS and Android
* Supports Flutter Web through sembast_web.
* Supports Dart VM (Desktop) through sembast

See [sembast](https://github.com/tekartik/sembast.dart) for API usage

## Setup

[Setup instructions](https://github.com/tekartik/sembast_sqflite/tree/master/sembast_sqflite/doc/setup.md) for all 
platforms (Flutter/VM, iOS/Android/MacOS, Windows/Linux)

## Why

You might wonder why...sembast already has its own io format. However sembast io is not cross process safe and one
might consider that it is not a well known robust database system.

Here sqflite is used as the based of a journal database that provides data to sembast, allowing a fast all-in-memory 
access and safe cross process database storage and transaction mechanism.

