# Storage format

Applications should not rely on this storage format: it can change (2.2.4 already changed the schema of new
databases: `store` and `key` are `NOT NULL`, no separate `record` index). Meta information is managed by sembast.

Instead applications should [export/import](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/storage_format.md#importexport) a database content.

Current sembast_sqflite database format is the following:
* A table `entry` holding each record content with the following fields
    - `id` auto-incremented sqlite record id, it is also the revision of the change
    - `store` the name of the store the records belong to
    - `key` the record key in the store (an INTEGER or a TEXT value)
    - `value` the json encoded value of the record (the codec output when the database has a codec), NULL for a
      deleted record
    - `deleted` 1 when the record has been deleted, NULL otherwise

  Each write replaces the row of the record (one row per store and key) by a new one with a new `id`. Deleted rows
  are removed when the database is compacted (on open, or `db.compact()`).

Example for a notepad store (`StoreRef<int, Map<String, Object?>>`), note 3 deleted:

| id |store|key|value|deleted|
|----|-----|---|-----|-------|
| 1 |notes|1|{"title":"My note 1"}| |
| 2 |notes|2|{"title":"My note 2"}| |
| 4 |notes|3| |1|

Example for a simple `StoreRef<String, String>` (the value is json encoded, hence the quotes):

| id |store|key|value|
|----|-----|---|-----|
| 5 |_main|username|"my_username"|
| 6 |_main|url|"my_url"|

* A table `info` holding some meta information
    - `id` key of the info (string)
    - `value` json encoded value of the info (string)

| id | value | notes |
|----|-------|-------|
|meta|{"version":1,"sembast":1}|sembast signature and versioning (plus the codec signature if any)|
|revision|6|global database revision, the last `entry` id written|
|notes_store_last_id|3|last auto increment key for store `notes`|
|deltaMinRevision|4|the last deleted row removed by a compaction: another process that has not seen this revision reloads everything|
