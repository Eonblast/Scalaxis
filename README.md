Scalaxis
========

This is a dirty experimental fork of Scalaris [http://code.google.com/p/scalaris/] to experiment with

* disk persistence
* external interface
* atomic operations
* noc distribution
* query extensions
* link walking
* having a community


Especially the first, but also the second are dearly missing from Scalaris in our view. The last would be cool and hopefully translate into a community for Scalaris proper.


Fork Objectives
===============

This fork exists so we have freedom to wreak havoc on the code to try things out.

We think it's one of the strongest free KV on the planet. Says Richard Jones of lastfm: "Scalaris is probably the most face-meltingly awesome thing you could build in Erlang. CouchDB, Ejabberd and RabbitMQ are cool, but Scalaris packs by far the most impressive collection of sexy technologies." And Joe Armstrong hoped: "my gut feeling is [Scalaris] will be the first killer application in Erlang" and "one of the sexiest applications I've seen in many a year. I've been waiting for this to happen for a long while. The work is backed by quadzillion Ph.D's"

So go check it out. The real Scalaris can be found at Google Code: [http://code.google.com/p/scalaris/]

Trying things out is exactly NOT how the original, Scalaris, is operated, which is what we appreciate about it. Thorsten has strong principles and won't sell them out for mere considerations of practicality. Well, we will. 

Anything that matures in this fork may hopefully find it's way into the original one day.


Disk Persistence
----------------

Disk persistence haunts Scalaris' fate since inception. People regularly diss Scalaris before thinking things through.

We want to add disk persistence. Let's discuss what makes sense. There is an academic view and a practical perspective.

It makes a lot of sense to have a means to write stuff to disk while developing. It also makes a lot of sense to make snapshots, preferably consistent across all nodes, to have a backup of last resort. Way better than not having anything at all. 

It also makes a lot of sense to be able to say "I propose a database system that has disk persistence" as opposed to "I propose a database system that has no disk persistence". That's the softest point and at the same time the strongest issue that we feel must be addressed for Scalaris ever to become a player.

Beyond that let's face it: Scalaris is designed for huge databases that span thousands of servers. That are always live, never go down, seamlessly replace each other on failure and serve the data from memory. Eventually, Scalaris is meant to be memory-only. It's not meant to be stopped, especially not for maintenance. But it may be in dire need of training wheels.  

The reality is that of developers who need to stop and restart their stuff and of managers who have to argue with people even less interested in the technical fine print than they themselves are. "No disk persistence" won't fly, neither for developing nor in-house selling.

What level of persistence will do? We'll start easy. System stop and restart. Then, live Snapshots. Then the real thing, with sensible constraints, like crawl mode to phase into a system wide consistent disk image. Practical stuff that doesn't hurt the academic cleanliness of Scalaris too bad. 

We are not talking about the Tokyo Cabinet capacity enhancement here that Scalaris features. That is really but using the disk as memory extension. 


External Interface
------------------

Erlang does not provide for functions to be passed around between nodes, which lead to a bit of a design weakness of Scalaris. But then, other DBs have to make an effort to ship around their stored procedures to all their partitions as well.

We want to find out how transporting query functionality into the running Scalaris nodes can be made safe and convenient. In essence, you want to be able to write functions, test them and then automatically deploy them across all nodes.


Atomic Operations
-----------------

What we should need for daily use are atomic operations that reliably increment or decrement specific fields, and that we don't need to hear back from unless they fail their constraints, in which case the entire transaction should fail. We want to try how close we can get to a generic interface for that, maybe building on the existing JSON interface.


NOC Distribution
----------------

Ideally you want to have copies of data spread around multiple NOCs to survive catastrophic failures at any one location.

This incurs high costs for protocol roundtrips for every data mutation. We'd like to find out what happens if the quorum is spread out over multiple network operation centers (NOCs) in an intelligent way.


Query Extensions
----------------

There are reasons to avoid NoSQLs. We want to explore how some basic query possibilities, maybe supported by (dirty) index data, can alleviate that grief.

It's not necessarily about random access data warehousing, but allowing for well planned, filtered traversals across the data base.


Link Walking
------------

We want to explore what kind of graphs could be implemented on the cheap, and how pattern matching link walking could be bolted on top of the existing key system. 

More
----

There is more, some of the stuff is internal and we won't share the source of it but built awful hooks into this fork for it. That's life. We'll try not to be unreasonably cruel though.




License
-------

Scalaxis: Copyright (C) 2010 Eonblast Corporation

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 3.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.


Scalaris: Copyright (C) 2007-2010 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin
 
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
 
        http://www.apache.org/licenses/LICENSE-2.0
 
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
