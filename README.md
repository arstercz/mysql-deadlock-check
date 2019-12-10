## mysql-deadlock-check

collect MySQL deadlocks. read more from [pt-deadlock-logger](https://www.percona.com/doc/percona-toolkit/3.0/pt-deadlock-logger.html) and [blog](https://blog.arstercz.com/%e6%9c%89%e6%95%88%e6%94%b6%e9%9b%86-mysql-%e7%9a%84%e6%ad%bb%e9%94%81%e4%bf%a1%e6%81%af/).

## How to use?

`mysql-deadlock-check` collect and parse MySQL deadlocks, then send to analysis database. such as:
```
  +-----+
  | DB1 |  ----------+
  +-----+            |
  +-----+            |    +----------------+             +-----------------+
  | DB2 |  ----------+--> | deadlock-check | ----------> | DB for analysis |
  +-----+            |    +----------------+             +-----------------+
    ...              |
  +-----+            |
  | DBn |  ----------+
  +-----+

```

### Dependency
```
perl-DBI
perl-DBD-MySQL
perl-Time-HiRes
perl-TermReadKey
perl-TimeDate
perl-Digest-MD5   (if use Centos 7)
perl-Data-Dumper （if use Centos 7）
```

### Configure file

you can add MySQL instance list into `etc/host.list`, such as:
```
# host port
10.0.21.5 3301
10.0.21.6 3302
......
```
the parameters of the `pt-deadlock-logger` can be add in `etc/pt.conf`, mainly include:
```
tag=Beijing
user=user_check
password=xxxxxxxxxx
interval=60
iterations=1
set-vars=wait_timeout=10000
dest=h=10.0.21.10,P=3306,D=deadlock_check,t=deadlocks,u=user_deadlock,p=xxxxxxxxx
```
the parameter description is as follows:
```
tag:  identify the MySQL instance, this can be location, rack or project name;
user: the username of the MySQL instance, all MySQL instances in host.list must have the same user and password;
password: the password of the MySQL instance;
interval: collect once every interval time if you don't give the interations value;
interations: the check times to execute, 1 means just check one interval time before exit;
set-vars: change session parameter when connect to MySQL instance;
dest:  the analysis database connection info, all deadlocks will send to this dest's database;
```

### Permission

the permission consists of two parts:

#### dest privilges
all deadlocks will send to this dest's database, so the dest's database must create database, table and user:
```
create database deadlock_check;
use deadlock_check;
grant select,insert,update,delete on deadlock_check.* to user_deadlock@`10.xxx.xxx.xxx.%`;

CREATE TABLE `deadlocks` (
  `server` varchar(30) NOT NULL,
  `ts` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `tm` int(11) NOT NULL DEFAULT '0',
  `thread` int(10) unsigned NOT NULL,
  `txn_id` bigint(20) unsigned NOT NULL,
  `txn_time` smallint(5) unsigned NOT NULL,
  `user` char(16) NOT NULL,
  `hostname` char(20) NOT NULL,
  `ip` char(15) NOT NULL,
  `db` char(64) NOT NULL,
  `tbl` char(64) NOT NULL,
  `idx` char(64) NOT NULL,
  `lock_type` char(16) NOT NULL,
  `lock_mode` varchar(20) NOT NULL,
  `wait_hold` varchar(3) NOT NULL,
  `victim` tinyint(3) unsigned NOT NULL,
  `query` text NOT NULL,
  `tag` varchar(50) NOT NULL DEFAULT '',
  `finger` varchar(100) NOT NULL DEFAULT '',
  `origmsg` text NOT NULL,
  PRIMARY KEY (`server`,`ts`,`thread`),
  KEY `idx_ts` (`ts`),
  KEY `idx_finger` (`finger`),
  KEY `idx_tm` (`tm`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
```

#### MySQL instance

the MySQL to be checked needs the following privilges:
```
grant process on *.* to user_deadlcok@`xxx.xxx.xxx.%`
```

### How to start

`start_mysql_deadlock.sh` will start five process every once:
```
cd mysql-deadlock-check
bash start_mysql_deadlock.sh
```

### How to analysis

You can read the dest's database wich incremental approach, the other(such as frequency, trend) can be use Grafana, the following is the sample deadlock:
```
server : 10.0.21.5:3308
ts : 2019-05-26 09:54:12
thread : 109954
txn_id : 306881983001
txn_time : 0
user : user_log
hostname :
ip : 10.0.21.17
db : user_log
tbl : login_log
idx : GEN_CLUST_INDEX
lock_type : RECORD
lock_mode : X
wait_hold : w
victim : 0
query : update login_log set amount=amount+1, update_time=now() where user_id=458122745 and city_id=430800

server : 10.0.21.5:3308
ts : 2019-05-26 09:54:12
thread : 112021
txn_id : 306881983024
txn_time : 0
user : user_log
hostname :
ip : 10.0.21.17
db : user_log
tbl : login_log
idx : idx_logid
lock_type : RECORD
lock_mode : X
wait_hold : hw
victim : 1
query : update login_log set amount=amount+1, update_time=now() where user_id=458210063 and city_id=430800
```
The field information is identified as follows:
```
server:     the ip:port message;
ts:         the time occurs the deadlock;
thread:     the thread id tha the transaction and connect use;
txn_id:     the if of the transaction;
txn_time:   the execute time of the transaction;
user:       the user of the transaction;
hostname:   the hostname of the connect host;
ip:         the ip of the connect host;
db:         the database of the transaction used;
tb1:        the table of the transaction used;
idx:        the index key that transaction used;
lock_type:  the lock type that transaction hold;
lock_mode:  the lock mode(S, X);
wait_hold:  whether the lock is hold(h) or wait(w);
victim:     1 means this transaction was rollback;
query:      the query of the tansaction;
```

### The impact on the MySQL instance

`mysql-deadlock-check` only execute the following query, this will return many data if MySQL have manay transactions:
```
SHOW ENGINE INNODB STATUS
```

### changelog

compared to the official `pt-deadlock-logger` tools, we have made the following changes:
```
1. change the server filed wich ip:port format to identify multiple instance running on one host;
2. add the tag filed to identify location, rack or project;
3. add finger filed to avoid repeate insert the deadlock messages;
4. add origmsg filed to record the original deadlock message;
5. fix the Chinese garbled when to send deadlocks to analysis database;
```
