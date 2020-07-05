# Storage format

Application should not assume any storage format as it could change (although it has not changed since the beginning yet).
While it is stored in a SQLite file (with a fixed schema) internal meta information is managed by sembast.

Instead applications should [export/import](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/storage_format.md#importexport) a database content.

Current sembast_sqflite database format is the following:
* A table `entry` holding each record content with the following fields
    - `id` auto-incremented sqlite record id
    - `store` the name of the store the records belong to
    - `key` the record key in the store
    - `value` the json encoded value of the record
    - `deleted` whether the record has been deleted

Example for a notepad store (StoreRef<int, Map<String, dynamic>):

| id |store|key|value|deleted|
|----|-----|---|-----|-------|    
|12979|notes|1|{"title":"My note 1","content":"some content"}|	
|12980|notes|2|{"title":"My note 1","content":"some other content"}|
|12981|notes|3|{"deleted":true}|

Example for a simple StoreRef<String, String>:

| id |store|key|value|
|----|-----|---|-----|    
| 1|_main|username|my_username|	
| 2 |_main|url|my_url|
    
* A table `info` holding some meta information
    - `id` key of the info (string)
    - `value` value of the info (string)
	

| id | value | notes |
|----|-------|-------|
|meta|{"version":1,""sembast":1}|sembast signature and versioning|
|revision|2|global database revision - incremented internally|
|notes_store_last_id|3|last auto increment for store `notes`|
