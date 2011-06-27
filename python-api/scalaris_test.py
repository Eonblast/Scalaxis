#!/usr/bin/python
# Copyright 2011 Zuse Institute Berlin
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

from scalaris import TransactionSingleOp, Transaction, PubSub, ReplicatedDHT
import scalaris
import time, threading, json
from datetime import datetime
from BaseHTTPServer import HTTPServer, BaseHTTPRequestHandler
import unittest

# wait that long for subscription notifications to arrive
_NOTIFICATIONS_TIMEOUT = 60;

_TEST_DATA = [
             "ahz2ieSh", "wooPhu8u", "quai9ooK", "Oquae4ee", "Airier1a", "Boh3ohv5", "ahD3Saog", "EM5ooc4i", 
             "Epahrai8", "laVahta7", "phoo6Ahj", "Igh9eepa", "aCh4Lah6", "ooT0ath5", "uuzau4Ie", "Iup6mae6", 
#             "xie7iSie", "ail8yeeP", "ooZ4eesi", "Ahn7ohph", "Ohy5moo6", "xooSh9Oo", "ieb6eeS7", "Thooqu9h", 
#             "eideeC9u", "phois3Ie", "EimaiJ2p", "sha6ahR1", "Pheih3za", "bai4eeXe", "rai0aB7j", "xahXoox6", 
#             "Xah4Okeg", "cieG8Yae", "Pe9Ohwoo", "Eehig6ph", "Xe7rooy6", "waY2iifu", "kemi8AhY", "Che7ain8", 
#             "ohw6seiY", "aegh1oBa", "thoh9IeG", "Kee0xuwu", "Gohng8ee", "thoh9Chi", "aa4ahQuu", "Iesh5uge", 
#             "Ahzeil8n", "ieyep5Oh", "xah3IXee", "Eefa5qui", "kai8Muuf", "seeCe0mu", "cooqua5Y", "Ci3ahF6z", 
#             "ot0xaiNu", "aewael8K", "aev3feeM", "Fei7ua5t", "aeCa6oph", "ag2Aelei", "Shah1Pho", "ePhieb0N", 
#             "Uqu7Phup", "ahBi8voh", "oon3aeQu", "Koopa0nu", "xi0quohT", "Oog4aiph", "Aip2ag5D", "tirai7Ae", 
#             "gi0yoePh", "uay7yeeX", "aeb6ahC1", "OoJeic2a", "ieViom1y", "di0eeLai", "Taec2phe", "ID2cheiD", 
#             "oi6ahR5M", "quaiGi8W", "ne1ohLuJ", "DeD0eeng", "yah8Ahng", "ohCee2ie", "ecu1aDai", "oJeijah4", 
#             "Goo9Una1", "Aiph3Phi", "Ieph0ce5", "ooL6cae7", "nai0io1H", "Oop2ahn8", "ifaxae7O", "NeHai1ae", 
#             "Ao8ooj6a", "hi9EiPhi", "aeTh9eiP", "ao8cheiH", "Yieg3sha", "mah7cu2D", "Uo5wiegi", "Oowei0ya", 
#             "efeiDee7", "Oliese6y", "eiSh1hoh", "Joh6hoh9", "zib6Ooqu", "eejiJie4", "lahZ3aeg", "keiRai1d", 
#             "Fei0aewe", "aeS8aboh", "hae3ohKe", "Een9ohQu", "AiYeeh7o", "Yaihah4s", "ood4Giez", "Oumai7te", 
#             "hae2kahY", "afieGh4v", "Ush0boo0", "Ekootee5", "Ya8iz6Ie", "Poh6dich", "Eirae4Ah", "pai8Eeme", 
#             "uNah7dae", "yo3hahCh", "teiTh7yo", "zoMa5Cuv", "ThiQu5ax", "eChi5caa", "ii9ujoiV", "ge7Iekui",
             "sai2aiTa", "ohKi9rie", "ei2ioChu", "aaNgah9y", "ooJai1Ie", "shoh0oH9", "Ool4Ahya", "poh0IeYa", 
             "Uquoo0Il", "eiGh4Oop", "ooMa0ufe", "zee6Zooc", "ohhao4Ah", "Uweekek5", "aePoos9I", "eiJ9noor", 
             "phoong1E", "ianieL2h", "An7ohs4T", "Eiwoeku3", "sheiS3ao", "nei5Thiw", "uL5iewai", "ohFoh9Ae"]

class TestTransactionSingleOp(unittest.TestCase):
    def setUp(self):
        # The time when the test suite was started.
        now = datetime.now()
        # This is used to create different erlang keys for each run.
        self._testTime = int(time.mktime(now.timetuple()) * 1000 + (now.microsecond / 1000.0))

    # Test method for TransactionSingleOp()
    def testTransactionSingleOp1(self):
        conn = TransactionSingleOp()
        conn.close_connection()

    # Test method for TransactionSingleOp(conn)
    def testTransactionSingleOp2(self):
        conn = TransactionSingleOp(conn = scalaris.JSONConnection(url = scalaris.DEFAULT_URL))
        conn.close_connection()

    # Test method for TransactionSingleOp.close_connection() trying to close the connection twice.
    def testDoubleClose(self):
        conn = TransactionSingleOp()
        conn.close_connection()
        conn.close_connection()

    # Test method for TransactionSingleOp.read(key)
    def testRead_NotFound(self):
        key = "_Read_NotFound"
        conn = TransactionSingleOp()
        self.assertRaises(scalaris.NotFoundError, conn.read, str(self._testTime) + key)
        conn.close_connection()

    # Test method for TransactionSingleOp.read(key) with a closed connection.
    def testRead_NotConnected(self):
        key = "_Read_NotConnected"
        conn = TransactionSingleOp()
        conn.close_connection()
        #self.assertRaises(scalaris.ConnectionError, conn.read, str(self._testTime) + key)
        self.assertRaises(scalaris.NotFoundError, conn.read, str(self._testTime) + key)
        conn.close_connection()

    # Test method for TransactionSingleOp.write(key, value=str()) with a closed connection.
    def testWriteString_NotConnected(self):
        key = "_WriteString_NotConnected"
        conn = TransactionSingleOp()
        conn.close_connection()
        #self.assertRaises(scalaris.ConnectionError, conn.write, str(self._testTime) + key, _TEST_DATA[0])
        conn.write(str(self._testTime) + key, _TEST_DATA[0])
        conn.close_connection()

    # Test method for TransactionSingleOp.write(key, value=str()) and TransactionSingleOp.read(key).
    # Writes strings and uses a distinct key for each value. Tries to read the data afterwards.
    def testWriteString1(self):
        key = "_WriteString1_"
        conn = TransactionSingleOp()
        
        for i in xrange(len(_TEST_DATA)):
            conn.write(str(self._testTime) + key + str(i), _TEST_DATA[i])
        
        # now try to read the data:
        for i in xrange(len(_TEST_DATA)):
            actual = conn.read(str(self._testTime) + key + str(i))
            self.assertEqual(actual, _TEST_DATA[i])
        
        conn.close_connection()

    # Test method for TransactionSingleOp.write(key, value=str()) and TransactionSingleOp.read(key).
    # Writes strings and uses a single key for all the values. Tries to read the data afterwards.
    def testWriteString2(self):
        key = "_WriteString2"
        conn = TransactionSingleOp()
        
        for i in xrange(len(_TEST_DATA)):
            conn.write(str(self._testTime) + key, _TEST_DATA[i])
        
        # now try to read the data:
        actual = conn.read(str(self._testTime) + key)
        self.assertEqual(actual, _TEST_DATA[len(_TEST_DATA) - 1])
        conn.close_connection()

    # Test method for TransactionSingleOp.write(key, value=list()) with a closed connection.
    def testWriteList_NotConnected(self):
        key = "_WriteList_NotConnected"
        conn = TransactionSingleOp()
        conn.close_connection()
        #self.assertRaises(scalaris.ConnectionError, conn.write, str(self._testTime) + key, [_TEST_DATA[0], _TEST_DATA[1]])
        conn.write(str(self._testTime) + key, [_TEST_DATA[0], _TEST_DATA[1]])
        conn.close_connection()

    # Test method for TransactionSingleOp.write(key, value=list()) and TransactionSingleOp.read(key).
    # Writes strings and uses a distinct key for each value. Tries to read the data afterwards.
    def testWriteList1(self):
        key = "_WriteList1_"
        conn = TransactionSingleOp()
        
        for i in xrange(0, len(_TEST_DATA) - 1, 2):
            conn.write(str(self._testTime) + key + str(i), [_TEST_DATA[i], _TEST_DATA[i + 1]])
        
        # now try to read the data:
        for i in xrange(0, len(_TEST_DATA), 2):
            actual = conn.read(str(self._testTime) + key + str(i))
            self.assertEqual(actual, [_TEST_DATA[i], _TEST_DATA[i + 1]])
        
        conn.close_connection()

    # Test method for TransactionSingleOp.write(key, value=list()) and TransactionSingleOp.read(key).
    # Writes strings and uses a single key for all the values. Tries to read the data afterwards.
    def testWriteList2(self):
        key = "_WriteList2"
        conn = TransactionSingleOp()
        
        list = []
        for i in xrange(0, len(_TEST_DATA) - 1, 2):
            list = [_TEST_DATA[i], _TEST_DATA[i + 1]]
            conn.write(str(self._testTime) + key, list)
        
        # now try to read the data:
        actual = conn.read(str(self._testTime) + key)
        self.assertEqual(actual, list)
        conn.close_connection()

    # Test method for TransactionSingleOp.test_and_set(key, oldvalue=str(), newvalue=str()) with a closed connection.
    def testTestAndSetString_NotConnected(self):
        key = "_TestAndSetString_NotConnected"
        conn = TransactionSingleOp()
        conn.close_connection()
        #self.assertRaises(scalaris.ConnectionError, conn.test_and_set, str(self._testTime) + key, _TEST_DATA[0], _TEST_DATA[1])
        self.assertRaises(scalaris.NotFoundError, conn.test_and_set, str(self._testTime) + key, _TEST_DATA[0], _TEST_DATA[1])
        conn.close_connection()
    
    # Test method for TransactionSingleOp.test_and_set(key, oldvalue=str(), newvalue=str()).
    # Tries test_and_set with a non-existing key.
    def testTestAndSetString_NotFound(self):
        key = "_TestAndSetString_NotFound"
        conn = TransactionSingleOp()
        self.assertRaises(scalaris.NotFoundError, conn.test_and_set, str(self._testTime) + key, _TEST_DATA[0], _TEST_DATA[1])
        conn.close_connection()

    # Test method for TransactionSingleOp.test_and_set(key, oldvalue=str(), newvalue=str()),
    # TransactionSingleOp.read(key) and TransactionSingleOp.write(key, value=str()).
    # Writes a string and tries to overwrite it using test_and_set
    # knowing the correct old value. Tries to read the string afterwards.
    def testTestAndSetString1(self):
        key = "_TestAndSetString1"
        conn = TransactionSingleOp()
        
        # first write all values:
        for i in xrange(0, len(_TEST_DATA) - 1, 2):
            conn.write(str(self._testTime) + key + str(i), _TEST_DATA[i])
        
        # now try to overwrite them using test_and_set:
        for i in xrange(0, len(_TEST_DATA) - 1, 2):
            conn.test_and_set(str(self._testTime) + key + str(i), _TEST_DATA[i], _TEST_DATA[i + 1])
        
        # now try to read the data:
        for i in xrange(0, len(_TEST_DATA), 2):
            actual = conn.read(str(self._testTime) + key + str(i))
            self.assertEqual(actual, _TEST_DATA[i + 1])
        
        conn.close_connection()

    # Test method for TransactionSingleOp.test_and_set(key, oldvalue=str(), newvalue=str()),
    # TransactionSingleOp.read(key) and TransactionSingleOp.write(key, value=str()).
    # Writes a string and tries to overwrite it using test_and_set
    # knowing the wrong old value. Tries to read the string afterwards.
    def testTestAndSetString2(self):
        key = "_TestAndSetString2"
        conn = TransactionSingleOp()
        
        # first write all values:
        for i in xrange(0, len(_TEST_DATA) - 1, 2):
            conn.write(str(self._testTime) + key + str(i), _TEST_DATA[i])
        
        # now try to overwrite them using test_and_set:
        for i in xrange(0, len(_TEST_DATA) - 1, 2):
            try:
                conn.test_and_set(str(self._testTime) + key + str(i), _TEST_DATA[i + 1], "fail")
                self.fail('expected a KeyChangedError')
            except scalaris.KeyChangedError as exception:
                self.assertEqual(exception.old_value, _TEST_DATA[i])
        
        # now try to read the data:
        for i in xrange(0, len(_TEST_DATA), 2):
            actual = conn.read(str(self._testTime) + key + str(i))
            self.assertEqual(actual, _TEST_DATA[i])
        
        conn.close_connection()

    # Test method for TransactionSingleOp.test_and_set(key, oldvalue=str(), newvalue=list()) with a closed connection.
    def testTestAndSetList_NotConnected(self):
        key = "_TestAndSetList_NotConnected"
        conn = TransactionSingleOp()
        conn.close_connection()
        #self.assertRaises(scalaris.ConnectionError, conn.test_and_set, str(self._testTime) + key, "fail", [_TEST_DATA[0], _TEST_DATA[1]])
        self.assertRaises(scalaris.NotFoundError, conn.test_and_set, str(self._testTime) + key, "fail", [_TEST_DATA[0], _TEST_DATA[1]])
        conn.close_connection()
    
    # Test method for TransactionSingleOp.test_and_set(key, oldvalue=str(), newvalue=list()).
    # Tries test_and_set with a non-existing key.
    def testTestAndSetList_NotFound(self):
        key = "_TestAndSetList_NotFound"
        conn = TransactionSingleOp()
        self.assertRaises(scalaris.NotFoundError, conn.test_and_set, str(self._testTime) + key, "fail", [_TEST_DATA[0], _TEST_DATA[1]])
        conn.close_connection()
    
    # Test method for TransactionSingleOp.test_and_set(key, oldvalue=str(), newvalue=list()),
    # TransactionSingleOp.read(key) and TransactionSingleOp.write(key, value=list()).
    # Writes a list and tries to overwrite it using test_and_set
    # knowing the correct old value. Tries to read the string afterwards.
    def testTestAndSetList1(self):
        key = "_TestAndSetList1"
        conn = TransactionSingleOp()
        
        # first write all values:
        for i in xrange(0, len(_TEST_DATA) - 1, 2):
            conn.write(str(self._testTime) + key + str(i), [_TEST_DATA[i], _TEST_DATA[i + 1]])
        
        # now try to overwrite them using test_and_set:
        for i in xrange(0, len(_TEST_DATA) - 1, 2):
            conn.test_and_set(str(self._testTime) + key + str(i), [_TEST_DATA[i], _TEST_DATA[i + 1]], [_TEST_DATA[i + 1], _TEST_DATA[i]])
        
        # now try to read the data:
        for i in xrange(0, len(_TEST_DATA) - 1, 2):
            actual = conn.read(str(self._testTime) + key + str(i))
            self.assertEqual(actual, [_TEST_DATA[i + 1], _TEST_DATA[i]])
        
        conn.close_connection()

    # Test method for TransactionSingleOp.test_and_set(key, oldvalue=str(), newvalue=list()),
    # TransactionSingleOp.read(key) and TransactionSingleOp.write(key, value=list()).
    # Writes a string and tries to overwrite it using test_and_set
    # knowing the wrong old value. Tries to read the string afterwards.
    def testTestAndSetList2(self):
        key = "_TestAndSetList2"
        conn = TransactionSingleOp()
        
        # first write all values:
        for i in xrange(0, len(_TEST_DATA) - 1, 2):
            conn.write(str(self._testTime) + key + str(i), [_TEST_DATA[i], _TEST_DATA[i + 1]])
        
        # now try to overwrite them using test_and_set:
        for i in xrange(0, len(_TEST_DATA) - 1, 2):
            try:
                conn.test_and_set(str(self._testTime) + key + str(i), "fail", 1)
                self.fail('expected a KeyChangedError')
            except scalaris.KeyChangedError as exception:
                self.assertEqual(exception.old_value, [_TEST_DATA[i], _TEST_DATA[i + 1]])
        
        # now try to read the data:
        for i in xrange(0, len(_TEST_DATA) - 1, 2):
            actual = conn.read(str(self._testTime) + key + str(i))
            self.assertEqual(actual, [_TEST_DATA[i], _TEST_DATA[i + 1]])
        
        conn.close_connection()

    # Test method for TransactionSingleOp.req_list(RequestList) with an
    # empty request list.
    def testReqList_Empty(self):
        conn = TransactionSingleOp()
        conn.req_list(conn.new_req_list())
        conn.close_connection()

    # Test method for TransactionSingleOp.req_list(RequestList) with a
    # mixed request list.
    def testReqList1(self):
        key = "_ReqList1_"
        conn = TransactionSingleOp()
        
        readRequests = conn.new_req_list()
        firstWriteRequests = conn.new_req_list()
        writeRequests = conn.new_req_list()
        for i in xrange(0, len(_TEST_DATA)):
            if (i % 2) == 0:
                firstWriteRequests.add_write(str(self._testTime) + key + str(i), _TEST_DATA[i])
            writeRequests.add_write(str(self._testTime) + key + str(i), _TEST_DATA[i])
            readRequests.add_read(str(self._testTime) + key + str(i))
        
        results = conn.req_list(firstWriteRequests)
        # evaluate the first write results:
        for i in xrange(0, firstWriteRequests.size()):
            conn.process_result_write(results[i])

        requests = conn.new_req_list(readRequests).extend(writeRequests)
        results = conn.req_list(requests)
        self.assertEqual(requests.size(), len(results))

        # now evaluate the read results:
        for i in xrange(0, readRequests.size()):
            if (i % 2) == 0:
                actual = conn.process_result_read(results[i])
                self.assertEqual(_TEST_DATA[i], actual)
            else:
                try:
                    conn.process_result_read(results[i])
                    # a not found exception must be thrown
                    self.fail('expected a NotFoundError')
                except scalaris.NotFoundError:
                    pass

        # now evaluate the write results:
        for i in xrange(0, writeRequests.size()):
            pos = readRequests.size() + i
            conn.process_result_write(results[pos])

        # once again test reads - now all reads should be successful
        results = conn.req_list(readRequests)
        self.assertEqual(readRequests.size(), len(results))

        # now evaluate the read results:
        for i in xrange(0, readRequests.size()):
            actual = conn.process_result_read(results[i])
            self.assertEqual(_TEST_DATA[i], actual)
        
        conn.close_connection();

class TestTransaction(unittest.TestCase):
    def setUp(self):
        # The time when the test suite was started.
        now = datetime.now()
        # This is used to create different erlang keys for each run.
        self._testTime = int(time.mktime(now.timetuple()) * 1000 + (now.microsecond / 1000.0))

    # Test method for Transaction()
    def testTransaction1(self):
        t = Transaction()
        t.close_connection()

    # Test method for Transaction(conn)
    def testTransaction3(self):
        t = Transaction(conn = scalaris.JSONConnection(url = scalaris.DEFAULT_URL))
        t.close_connection()

    # Test method for Transaction.close_connection() trying to close the connection twice.
    def testDoubleClose(self):
        t = Transaction()
        t.close_connection()
        t.close_connection()

    # Test method for Transaction.commit() with a closed connection.
    def testCommit_NotConnected(self):
        t = Transaction()
        t.close_connection()
        #self.assertRaises(scalaris.ConnectionError, t.commit)
        t.commit()
        t.close_connection()

    # Test method for Transaction.commit() which commits an empty transaction.
    def testCommit_Empty(self):
        t = Transaction()
        t.commit()
        t.close_connection()

    # Test method for Transaction.abort() with a closed connection.
    def testAbort_NotConnected(self):
        t = Transaction()
        t.close_connection()
        #self.assertRaises(scalaris.ConnectionError, t.abort)
        t.abort()
        t.close_connection()

    # Test method for Transaction.abort() which aborts an empty transaction.
    def testAbort_Empty(self):
        t = Transaction()
        t.abort()
        t.close_connection()

    # Test method for Transaction.read(key)
    def testRead_NotFound(self):
        key = "_Read_NotFound"
        t = Transaction()
        self.assertRaises(scalaris.NotFoundError, t.read, str(self._testTime) + key)
        t.close_connection()

    # Test method for Transaction.read(key) with a closed connection.
    def testRead_NotConnected(self):
        key = "_Read_NotConnected"
        t = Transaction()
        t.close_connection()
        #self.assertRaises(scalaris.ConnectionError, t.read, str(self._testTime) + key)
        self.assertRaises(scalaris.NotFoundError, t.read, str(self._testTime) + key)
        t.close_connection()

    # Test method for Transaction.write(key, value=str()) with a closed connection.
    def testWriteString_NotConnected(self):
        key = "_WriteString_NotConnected"
        t = Transaction()
        t.close_connection()
        #self.assertRaises(scalaris.ConnectionError, t.write, str(self._testTime) + key, _TEST_DATA[0])
        t.write(str(self._testTime) + key, _TEST_DATA[0])
        t.close_connection()

    # Test method for Transaction.read(key) and Transaction.write(key, value=str())
    # which should show that writing a value for a key for which a previous read
    # returned a NotFoundError is possible.
    def testWriteString_NotFound(self):
        key = "_WriteString_notFound"
        t = Transaction()
        notFound = False
        try:
            t.read(str(self._testTime) + key)
        except scalaris.NotFoundError:
            notFound = True
        
        self.assertTrue(notFound)
        t.write(str(self._testTime) + key, _TEST_DATA[0])
        self.assertEqual(t.read(str(self._testTime) + key), _TEST_DATA[0])
        t.close_connection()

    # Test method for Transaction.write(key, value=str()) and Transaction.read(key).
    # Writes strings and uses a distinct key for each value. Tries to read the data afterwards.
    def testWriteString(self):
        key = "_testWriteString1_"
        t = Transaction()
        
        for i in xrange(len(_TEST_DATA)):
            t.write(str(self._testTime) + key + str(i), _TEST_DATA[i])
        
        # now try to read the data:
        for i in xrange(len(_TEST_DATA)):
            actual = t.read(str(self._testTime) + key + str(i))
            self.assertEqual(actual, _TEST_DATA[i])
        
        # commit the transaction and try to read the data with a new one:
        t.commit()
        t = Transaction()
        for i in xrange(len(_TEST_DATA)):
            actual = t.read(str(self._testTime) + key + str(i))
            self.assertEqual(actual, _TEST_DATA[i])
        
        t.close_connection()

    # Test method for Transaction.write(key, value=list()) and Transaction.read(key).
    # Writes a list and uses a distinct key for each value. Tries to read the data afterwards.
    def testWriteList1(self):
        key = "_testWriteList1_"
        t = scalaris.Transaction()
        
        for i in xrange(0, len(_TEST_DATA) - 1, 2):
            t.write(str(self._testTime) + key + str(i), [_TEST_DATA[i], _TEST_DATA[i + 1]])
        
        # now try to read the data:
        for i in xrange(0, len(_TEST_DATA), 2):
            actual = t.read(str(self._testTime) + key + str(i))
            self.assertEqual(actual, [_TEST_DATA[i], _TEST_DATA[i + 1]])
        
        t.close_connection()
        
        # commit the transaction and try to read the data with a new one:
        t.commit()
        t = Transaction()
        for i in xrange(0, len(_TEST_DATA), 2):
            actual = t.read(str(self._testTime) + key + str(i))
            self.assertEqual(actual, [_TEST_DATA[i], _TEST_DATA[i + 1]])
        
        t.close_connection()

    # Test method for Transaction.req_list(RequestList) with an
    # empty request list.
    def testReqList_Empty(self):
        conn = Transaction()
        conn.req_list(conn.new_req_list())
        conn.close_connection()

    # Test method for Transaction.req_list(RequestList) with a
    # mixed request list.
    def testReqList1(self):
        key = "_ReqList1_"
        conn = Transaction()
        
        readRequests = conn.new_req_list()
        firstWriteRequests = conn.new_req_list()
        writeRequests = conn.new_req_list()
        for i in xrange(0, len(_TEST_DATA)):
            if (i % 2) == 0:
                firstWriteRequests.add_write(str(self._testTime) + key + str(i), _TEST_DATA[i])
            writeRequests.add_write(str(self._testTime) + key + str(i), _TEST_DATA[i])
            readRequests.add_read(str(self._testTime) + key + str(i))
        
        results = conn.req_list(firstWriteRequests)
        # evaluate the first write results:
        for i in xrange(0, firstWriteRequests.size()):
            conn.process_result_write(results[i])

        requests = conn.new_req_list(readRequests).extend(writeRequests).add_commit()
        results = conn.req_list(requests)
        self.assertEqual(requests.size(), len(results))

        # now evaluate the read results:
        for i in xrange(0, readRequests.size()):
            if (i % 2) == 0:
                actual = conn.process_result_read(results[i])
                self.assertEqual(_TEST_DATA[i], actual)
            else:
                try:
                    conn.process_result_read(results[i])
                    # a not found exception must be thrown
                    self.fail('expected a NotFoundError')
                except scalaris.NotFoundError:
                    pass

        # now evaluate the write results:
        for i in xrange(0, writeRequests.size()):
            pos = readRequests.size() + i
            conn.process_result_write(results[pos])

        # once again test reads - now all reads should be successful
        results = conn.req_list(readRequests)
        self.assertEqual(readRequests.size(), len(results))

        # now evaluate the read results:
        for i in xrange(0, readRequests.size()):
            actual = conn.process_result_read(results[i])
            self.assertEqual(_TEST_DATA[i], actual)
        
        conn.close_connection();

class TestPubSub(unittest.TestCase):
    def setUp(self):
        # The time when the test suite was started.
        now = datetime.now()
        # This is used to create different erlang keys for each run.
        self._testTime = int(time.mktime(now.timetuple()) * 1000 + (now.microsecond / 1000.0))
    
    # checks if there are more elements in list than in expectedElements and returns one of those elements
    @staticmethod
    def _getDiffElement(list, expectedElements):
        for e in expectedElements:
            list.remove(e)
        
        if len(list) > 0:
            return list[0]
        else:
            return None

    # Test method for PubSub()
    def testPubSub1(self):
        conn = PubSub()
        conn.close_connection()

    # Test method for PubSub(conn)
    def testPubSub2(self):
        conn = PubSub(conn = scalaris.JSONConnection(url = scalaris.DEFAULT_URL))
        conn.close_connection()

    # Test method for PubSub.close_connection() trying to close the connection twice.
    def testDoubleClose(self):
        conn = PubSub()
        conn.close_connection()
        conn.close_connection()

    # Test method for PubSub.publish(topic, content) with a closed connection.
    def testPublish_NotConnected(self):
        topic = "_Publish_NotConnected"
        conn = PubSub()
        conn.close_connection()
        #self.assertRaises(scalaris.ConnectionError, conn.publish, str(self._testTime) + topic, _TEST_DATA[0])
        conn.publish(str(self._testTime) + topic, _TEST_DATA[0])
        conn.close_connection()

    # Test method for PubSub.publish(topic, content).
    # Publishes some topics and uses a distinct key for each value.
    def testPublish1(self):
        topic = "_Publish1_"
        conn = PubSub()
        
        for i in xrange(len(_TEST_DATA)):
            conn.publish(str(self._testTime) + topic + str(i), _TEST_DATA[i])
        
        conn.close_connection()

    # Test method for PubSub.publish(topic, content).
    # Publishes some topics and uses a single key for all the values.
    def testPublish2(self):
        topic = "_Publish2"
        conn = PubSub()
        
        for i in xrange(len(_TEST_DATA)):
            conn.publish(str(self._testTime) + topic, _TEST_DATA[i])
        
        conn.close_connection()

    # Test method for PubSub.get_subscribers(topic) with a closed connection.
    def testGetSubscribersOtp_NotConnected(self):
        topic = "_GetSubscribers_NotConnected"
        conn = PubSub()
        conn.close_connection()
        #self.assertRaises(scalaris.ConnectionError, conn.get_subscribers, str(self._testTime) + topic)
        conn.get_subscribers(str(self._testTime) + topic)
        conn.close_connection()

    # Test method for PubSub.get_subscribers(topic).
    # Tries to get a subscriber list from an empty topic.
    def testGetSubscribers_NotExistingTopic(self):
        topic = "_GetSubscribers_NotExistingTopic"
        conn = PubSub()
        subscribers = conn.get_subscribers(str(self._testTime) + topic)
        self.assertEqual(subscribers, [])
        conn.close_connection()

    # Test method for PubSub.subscribe(topic url) with a closed connection.
    def testSubscribe_NotConnected(self):
        topic = "_Subscribe_NotConnected"
        conn = PubSub()
        conn.close_connection()
        #self.assertRaises(scalaris.ConnectionError, conn.subscribe, str(self._testTime) + topic, _TEST_DATA[0]) 
        conn.subscribe(str(self._testTime) + topic, _TEST_DATA[0])
        conn.close_connection()

    # Test method for PubSub.subscribe(topic, url) and PubSub.get_subscribers(topic).
    # Subscribes some arbitrary URLs to arbitrary topics and uses a distinct topic for each URL.
    def testSubscribe1(self):
        topic = "_Subscribe1_"
        conn = PubSub()
        
        for i in xrange(len(_TEST_DATA)):
            conn.subscribe(str(self._testTime) + topic + str(i), _TEST_DATA[i])
        
        # check if the subscribers were successfully saved:
        for i in xrange(len(_TEST_DATA)):
            topic1 = topic + str(i)
            subscribers = conn.get_subscribers(str(self._testTime) + topic1)
            self.assertTrue(_TEST_DATA[i] in subscribers,
                            msg = "Subscriber \"" + _TEST_DATA[i] + "\" does not exist for topic \"" + topic1 + "\"")
            self.assertEqual(len(subscribers), 1,
                            msg = "Subscribers of topic (" + topic1 + ") should only be [" + _TEST_DATA[i] + "], but is: " + repr(subscribers))
        
        conn.close_connection()

    # Test method for PubSub.subscribe(topic, url) and PubSub.get_subscribers(topic).
    # Subscribes some arbitrary URLs to arbitrary topics and uses a single topic for all URLs.
    def testSubscribe2(self):
        topic = "_Subscribe2"
        conn = PubSub()
        
        for i in xrange(len(_TEST_DATA)):
            conn.subscribe(str(self._testTime) + topic, _TEST_DATA[i])
        
        # check if the subscribers were successfully saved:
        subscribers = conn.get_subscribers(str(self._testTime) + topic)
        for i in xrange(len(_TEST_DATA)):
            self.assertTrue(_TEST_DATA[i] in subscribers,
                            msg = "Subscriber \"" + _TEST_DATA[i] + "\" does not exist for topic \"" + topic + "\"")
        self.assertEqual(self._getDiffElement(subscribers, _TEST_DATA), None,
                         msg = "unexpected subscriber of topic \"" + topic + "\"")
        
        conn.close_connection()

    # Test method for PubSub.unsubscribe(topic url) with a closed connection.
    def testUnsubscribe_NotConnected(self):
        topic = "_Unsubscribe_NotConnected"
        conn = PubSub()
        conn.close_connection()
        #self.assertRaises(scalaris.ConnectionError, conn.unsubscribe, str(self._testTime) + topic, _TEST_DATA[0])
        self.assertRaises(scalaris.NotFoundError, conn.unsubscribe, str(self._testTime) + topic, _TEST_DATA[0])
        conn.close_connection()

    # Test method for PubSub.unsubscribe(topic url) and PubSub.get_subscribers(topic).
    # Tries to unsubscribe an URL from a non-existing topic and tries to get the subscriber list afterwards.
    def testUnsubscribe_NotExistingTopic(self):
        topic = "_Unsubscribe_NotExistingTopic"
        conn = PubSub()
        # unsubscribe test "url":
        self.assertRaises(scalaris.NotFoundError, conn.unsubscribe, str(self._testTime) + topic, _TEST_DATA[0])
        
        # check whether the unsubscribed urls were unsubscribed:
        subscribers = conn.get_subscribers(str(self._testTime) + topic)
        self.assertFalse(_TEST_DATA[0] in subscribers,
                        msg = "Subscriber \"" + _TEST_DATA[0] + "\" should have been unsubscribed from topic \"" + topic + "\"")
        self.assertEqual(len(subscribers), 0,
                        msg = "Subscribers of topic (" + topic + ") should only be [], but is: " + repr(subscribers))
        
        conn.close_connection()

    # Test method for PubSub.subscribe(topic url), PubSub.unsubscribe(topic url) and PubSub.get_subscribers(topic).
    # Tries to unsubscribe an unsubscribed URL from an existing topic and compares the subscriber list afterwards.
    def testUnsubscribe_NotExistingUrl(self):
        topic = "_Unsubscribe_NotExistingUrl"
        conn = PubSub()
        
        # first subscribe test "urls"...
        conn.subscribe(str(self._testTime) + topic, _TEST_DATA[0])
        conn.subscribe(str(self._testTime) + topic, _TEST_DATA[1])
        
        # then unsubscribe another "url":
        self.assertRaises(scalaris.NotFoundError, conn.unsubscribe, str(self._testTime) + topic, _TEST_DATA[2])
        
        # check whether the subscribers were successfully saved:
        subscribers = conn.get_subscribers(str(self._testTime) + topic)
        self.assertTrue(_TEST_DATA[0] in subscribers,
                        msg = "Subscriber \"" + _TEST_DATA[0] + "\" does not exist for topic \"" + topic + "\"")
        self.assertTrue(_TEST_DATA[1] in subscribers,
                        msg = "Subscriber \"" + _TEST_DATA[1] + "\" does not exist for topic \"" + topic + "\"")
        
        # check whether the unsubscribed urls were unsubscribed:
        self.assertFalse(_TEST_DATA[2] in subscribers,
                        msg = "Subscriber \"" + _TEST_DATA[2] + "\" should have been unsubscribed from topic \"" + topic + "\"")
        
        self.assertEqual(len(subscribers), 2,
                        msg = "Subscribers of topic (" + topic + ") should only be [\"" + _TEST_DATA[0] + "\", \"" + _TEST_DATA[1] + "\"], but is: " + repr(subscribers))
        
        conn.close_connection()

    # Test method for PubSub.subscribe(topic url), PubSub.unsubscribe(topic url) and PubSub.get_subscribers(topic).
    # Subscribes some arbitrary URLs to arbitrary topics and uses a distinct topic for each URL.
    # Unsubscribes every second subscribed URL.
    def testUnsubscribe1(self):
        topic = "_UnsubscribeString1_"
        conn = PubSub()
        
        # first subscribe test "urls"...
        for i in xrange(len(_TEST_DATA)):
            conn.subscribe(str(self._testTime) + topic + str(i), _TEST_DATA[i])
        
        # ... then unsubscribe every second url:
        for i in xrange(0, len(_TEST_DATA), 2):
            conn.unsubscribe(str(self._testTime) + topic + str(i), _TEST_DATA[i])
        
        # check whether the subscribers were successfully saved:
        for i in xrange(1, len(_TEST_DATA), 2):
            topic1 = topic + str(i)
            subscribers = conn.get_subscribers(str(self._testTime) + topic1)
            self.assertTrue(_TEST_DATA[i] in subscribers,
                            msg = "Subscriber \"" + _TEST_DATA[i] + "\" does not exist for topic \"" + topic1 + "\"")
            self.assertEqual(len(subscribers), 1,
                            msg = "Subscribers of topic (" + topic1 + ") should only be [\"" + _TEST_DATA[i] + "\"], but is: " + repr(subscribers))
        
        # check whether the unsubscribed urls were unsubscribed:
        for i in xrange(0, len(_TEST_DATA), 2):
            topic1 = topic + str(i)
            subscribers = conn.get_subscribers(str(self._testTime) + topic1)
            self.assertFalse(_TEST_DATA[i] in subscribers,
                            msg = "Subscriber \"" + _TEST_DATA[i] + "\" should have been unsubscribed from topic \"" + topic1 + "\"")
            self.assertEqual(len(subscribers), 0,
                            msg = "Subscribers of topic (" + topic1 + ") should only be [], but is: " + repr(subscribers))
        
        conn.close_connection()

    # Test method for PubSub.subscribe(topic url), PubSub.unsubscribe(topic url) and PubSub.get_subscribers(topic).
    # Subscribes some arbitrary URLs to arbitrary topics and uses a single topic for all URLs.
    # Unsubscribes every second subscribed URL.
    def testUnsubscribe2(self):
        topic = "_UnubscribeString2"
        conn = PubSub()
        
        # first subscribe all test "urls"...
        for i in xrange(len(_TEST_DATA)):
            conn.subscribe(str(self._testTime) + topic, _TEST_DATA[i])
        
        # ... then unsubscribe every second url:
        for i in xrange(0, len(_TEST_DATA), 2):
            conn.unsubscribe(str(self._testTime) + topic, _TEST_DATA[i])
        
        # check whether the subscribers were successfully saved:
        subscribers = conn.get_subscribers(str(self._testTime) + topic)
        subscribers_expected = []
        for i in xrange(1, len(_TEST_DATA), 2):
            subscribers_expected.append(_TEST_DATA[i])
            self.assertTrue(_TEST_DATA[i] in subscribers,
                            msg = "Subscriber \"" + _TEST_DATA[i] + "\" does not exist for topic \"" + topic + "\"")
        
        # check whether the unsubscribed urls were unsubscribed:
        for i in xrange(0, len(_TEST_DATA), 2):
            self.assertFalse(_TEST_DATA[i] in subscribers,
                            msg = "Subscriber \"" + _TEST_DATA[i] + "\" should have been unsubscribed from topic \"" + topic + "\"")
        
        self.assertEqual(self._getDiffElement(subscribers, subscribers_expected), None,
                         msg = "unexpected subscriber of topic \"" + topic + "\"")
                        
        conn.close_connection()
    
    def _checkNotifications(self, notifications, expected):
        for (topic, contents) in expected.items():
            if topic not in notifications:
                notifications[topic] = []
            for content in contents:
                self.assertTrue(content in notifications[topic],
                                msg = "subscription (" + topic + ", " + content + ") not received by server)")
                notifications[topic].remove(content)
            if len(notifications[topic]) > 0:
                self.fail("Received element (" + topic + ", " + notifications[topic][0] + ") which is not part of the subscription.")
            del notifications[topic]
        # is there another (unexpected) topic we received content for?
        if len(notifications) > 0:
            for (topic, contents) in notifications.items():
                if len(contents) > 0:
                    self.fail("Received notification for topic (" + topic + ", " + contents[0] + ") which is not part of the subscription.")
                    break
    
    # Test method for the publish/subscribe system.
    # Single server, subscription to one topic, multiple publishs.
    def testSubscription1(self):
        topic = str(self._testTime) + "_Subscription1"
        conn = PubSub()
        server1 = self._newSubscriptionServer()
        notifications_server1_expected = {topic: []}
        ip1, port1 = server1.server_address
        
        conn.subscribe(topic, 'http://' + str(ip1) + ':' + str(port1))
        for i in xrange(len(_TEST_DATA)):
            conn.publish(topic, _TEST_DATA[i])
            notifications_server1_expected[topic].append(_TEST_DATA[i])
        
        # wait max '_NOTIFICATIONS_TIMEOUT' seconds for notifications:
        for i in xrange(_NOTIFICATIONS_TIMEOUT):
            if topic not in server1.notifications or len(server1.notifications[topic]) < len(notifications_server1_expected[topic]):
                time.sleep(1)
            else:
                break
        
        server1.shutdown()
        
        # check that every notification arrived:
        self._checkNotifications(server1.notifications, notifications_server1_expected)
        conn.close_connection()
    
    # Test method for the publish/subscribe system.
    # Three servers, subscription to one topic, multiple publishs.
    def testSubscription2(self):
        topic = str(self._testTime) + "_Subscription2"
        conn = PubSub()
        server1 = self._newSubscriptionServer()
        server2 = self._newSubscriptionServer()
        server3 = self._newSubscriptionServer()
        notifications_server1_expected = {topic: []}
        notifications_server2_expected = {topic: []}
        notifications_server3_expected = {topic: []}
        ip1, port1 = server1.server_address
        ip2, port2 = server2.server_address
        ip3, port3 = server3.server_address
        
        conn.subscribe(topic, 'http://' + str(ip1) + ':' + str(port1))
        conn.subscribe(topic, 'http://' + str(ip2) + ':' + str(port2))
        conn.subscribe(topic, 'http://' + str(ip3) + ':' + str(port3))
        for i in xrange(len(_TEST_DATA)):
            conn.publish(topic, _TEST_DATA[i])
            notifications_server1_expected[topic].append(_TEST_DATA[i])
            notifications_server2_expected[topic].append(_TEST_DATA[i])
            notifications_server3_expected[topic].append(_TEST_DATA[i])
        
        # wait max '_NOTIFICATIONS_TIMEOUT' seconds for notifications:
        for i in xrange(_NOTIFICATIONS_TIMEOUT):
            if (topic not in server1.notifications or len(server1.notifications[topic]) < len(notifications_server1_expected[topic])) or \
               (topic not in server2.notifications or len(server2.notifications[topic]) < len(notifications_server2_expected[topic])) or \
               (topic not in server3.notifications or len(server3.notifications[topic]) < len(notifications_server3_expected[topic])):
                time.sleep(1)
            else:
                break
        
        server1.shutdown()
        server2.shutdown()
        server3.shutdown()
        
        # check that every notification arrived:
        self._checkNotifications(server1.notifications, notifications_server1_expected)
        self._checkNotifications(server2.notifications, notifications_server2_expected)
        self._checkNotifications(server3.notifications, notifications_server3_expected)
        conn.close_connection()
    
    # Test method for the publish/subscribe system.
    # Three servers, subscription to different topics, multiple publishs, each
    # server receives a different number of elements.
    def testSubscription3(self):
        topic1 = str(self._testTime) + "_Subscription3_1"
        topic2 = str(self._testTime) + "_Subscription3_2"
        topic3 = str(self._testTime) + "_Subscription3_3"
        conn = PubSub()
        server1 = self._newSubscriptionServer()
        server2 = self._newSubscriptionServer()
        server3 = self._newSubscriptionServer()
        notifications_server1_expected = {topic1: []}
        notifications_server2_expected = {topic2: []}
        notifications_server3_expected = {topic3: []}
        ip1, port1 = server1.server_address
        ip2, port2 = server2.server_address
        ip3, port3 = server3.server_address
        
        conn.subscribe(topic1, 'http://' + str(ip1) + ':' + str(port1))
        conn.subscribe(topic2, 'http://' + str(ip2) + ':' + str(port2))
        conn.subscribe(topic3, 'http://' + str(ip3) + ':' + str(port3))
        for i in xrange(0, len(_TEST_DATA), 2):
            conn.publish(topic1, _TEST_DATA[i])
            notifications_server1_expected[topic1].append(_TEST_DATA[i])
        for i in xrange(0, len(_TEST_DATA), 3):
            conn.publish(topic2, _TEST_DATA[i])
            notifications_server2_expected[topic2].append(_TEST_DATA[i])
        for i in xrange(0, len(_TEST_DATA), 5):
            conn.publish(topic3, _TEST_DATA[i])
            notifications_server3_expected[topic3].append(_TEST_DATA[i])
        
        # wait max '_NOTIFICATIONS_TIMEOUT' seconds for notifications:
        for i in xrange(_NOTIFICATIONS_TIMEOUT):
            if (topic1 not in server1.notifications or len(server1.notifications[topic1]) < len(notifications_server1_expected[topic1])) or \
               (topic2 not in server2.notifications or len(server2.notifications[topic2]) < len(notifications_server2_expected[topic2])) or \
               (topic3 not in server3.notifications or len(server3.notifications[topic3]) < len(notifications_server3_expected[topic3])):
                time.sleep(1)
            else:
                break
        
        server1.shutdown()
        server2.shutdown()
        server3.shutdown()
        
        # check that every notification arrived:
        self._checkNotifications(server1.notifications, notifications_server1_expected)
        self._checkNotifications(server2.notifications, notifications_server2_expected)
        self._checkNotifications(server3.notifications, notifications_server3_expected)
        conn.close_connection()
    
    # Test method for the publish/subscribe system.
    # Like testSubscription3() but some subscribed urls will be unsubscribed.
    def testSubscription4(self):
        topic1 = str(self._testTime) + "_Subscription4_1"
        topic2 = str(self._testTime) + "_Subscription4_2"
        topic3 = str(self._testTime) + "_Subscription4_3"
        conn = PubSub()
        server1 = self._newSubscriptionServer()
        server2 = self._newSubscriptionServer()
        server3 = self._newSubscriptionServer()
        notifications_server1_expected = {topic1: []}
        notifications_server2_expected = {topic2: []}
        notifications_server3_expected = {topic3: []}
        ip1, port1 = server1.server_address
        ip2, port2 = server2.server_address
        ip3, port3 = server3.server_address
        
        conn.subscribe(topic1, 'http://' + str(ip1) + ':' + str(port1))
        conn.subscribe(topic2, 'http://' + str(ip2) + ':' + str(port2))
        conn.subscribe(topic3, 'http://' + str(ip3) + ':' + str(port3))
        conn.unsubscribe(topic2, 'http://' + str(ip2) + ':' + str(port2))
        for i in xrange(0, len(_TEST_DATA), 2):
            conn.publish(topic1, _TEST_DATA[i])
            notifications_server1_expected[topic1].append(_TEST_DATA[i])
        for i in xrange(0, len(_TEST_DATA), 3):
            conn.publish(topic2, _TEST_DATA[i])
            # note: topic2 is unsubscribed
            # notifications_server2_expected[topic2].append(_TEST_DATA[i])
        for i in xrange(0, len(_TEST_DATA), 5):
            conn.publish(topic3, _TEST_DATA[i])
            notifications_server3_expected[topic3].append(_TEST_DATA[i])
        
        # wait max '_NOTIFICATIONS_TIMEOUT' seconds for notifications:
        for i in xrange(_NOTIFICATIONS_TIMEOUT):
            if (topic1 not in server1.notifications or len(server1.notifications[topic1]) < len(notifications_server1_expected[topic1])) or \
               (topic3 not in server3.notifications or len(server3.notifications[topic3]) < len(notifications_server3_expected[topic3])):
                time.sleep(1)
            else:
                break
        
        server1.shutdown()
        server2.shutdown()
        server3.shutdown()
        
        # check that every notification arrived:
        self._checkNotifications(server1.notifications, notifications_server1_expected)
        self._checkNotifications(server2.notifications, notifications_server2_expected)
        self._checkNotifications(server3.notifications, notifications_server3_expected)
        conn.close_connection()

    @staticmethod
    def _newSubscriptionServer(server_address = ('localhost', 0)):
        server = TestPubSub.SubscriptionServer(server_address)
        #ip, port = server.server_address
    
        # Start a thread with the server
        server_thread = threading.Thread(target=server.serve_forever)
        # Exit the server thread when the main thread terminates
        server_thread.setDaemon(True)
        server_thread.start()
        #print "Server loop running in thread:", server_thread.getName()
    
        return server
    
    class SubscriptionServer(HTTPServer):
        def __init__(self, server_address):
            HTTPServer.__init__(self, server_address, TestPubSub.SubscriptionHandler)
            self.notifications = {}
    
    class SubscriptionHandler(BaseHTTPRequestHandler):
        def do_POST(self):
            if 'content-length' in self.headers and 'content-type' in self.headers:
                length = int(self.headers['content-length'])
                charset = self.headers['content-type'].split('charset=')
                if (len(charset) > 1):
                    encoding = charset[-1]
                else:
                    encoding = 'utf-8'
                data = self.rfile.read(length).decode(encoding)
                response_json = json.loads(data)
                # {"method":"notify","params":["1209386211287_SubscribeTest","content"],"id":482975}
                if 'method' in response_json and response_json['method'] == 'notify' \
                    and 'params' in response_json and 'id' in response_json \
                    and isinstance(response_json['params'], list) and len(response_json['params']) == 2:
                        topic = response_json['params'][0]
                        content = response_json['params'][1]
                        if hasattr(self.server, 'notifications'):
                            if topic not in self.server.notifications:
                                self.server.notifications[topic] = []
                            self.server.notifications[topic].append(content)
            else:
                pass
            
            response = '{}'.encode('utf-8')
            self.send_response(200)
            self.send_header("Content-type", "text/html; charset=utf-8")
            self.send_header("Content-length", str(len(response)))
            self.end_headers()
            self.wfile.write(response)
        
        # to disable logging
        def log_message(self, *args):
            pass

class TestReplicatedDHT(unittest.TestCase):
    def setUp(self):
        # The time when the test suite was started.
        now = datetime.now()
        # This is used to create different erlang keys for each run.
        self._testTime = int(time.mktime(now.timetuple()) * 1000 + (now.microsecond / 1000.0))

    # Test method for ReplicatedDHT()
    def testReplicatedDHT1(self):
        rdht = ReplicatedDHT()
        rdht.close_connection()

    # Test method for ReplicatedDHT(conn)
    def testReplicatedDHT2(self):
        rdht = ReplicatedDHT(conn = scalaris.JSONConnection(url = scalaris.DEFAULT_URL))
        rdht.close_connection()

    # Test method for ReplicatedDHT.close_connection() trying to close the connection twice.
    def testDoubleClose(self):
        rdht = ReplicatedDHT()
        rdht.close_connection()
        rdht.close_connection()
    
    # Tries to read the value at the given key and fails if this does
    # not fail with a NotFoundError.
    def _checkKeyDoesNotExist(self, key):
        conn = scalaris.TransactionSingleOp()
        try:
            conn.read(key)
            self.fail('the value at ' + key + ' should not exist anymore')
        except scalaris.NotFoundError:
            # nothing to do here
            pass
        conn.close_connection()

    # Test method for ReplicatedDHT.delete(key).
    # Tries to delete some not existing keys.
    def testDelete_notExistingKey(self):
        key = "_Delete_NotExistingKey"
        rdht = ReplicatedDHT()
        
        for i in xrange(len(_TEST_DATA)):
            ok = rdht.delete(str(self._testTime) + key + str(i))
            self.assertEqual(ok, 0)
            results = rdht.get_last_delete_result()
            self.assertEqual((results.ok, results.locks_set, results.undefined), (0, 0, 4))
            self._checkKeyDoesNotExist(str(self._testTime) + key + str(i))
        
        rdht.close_connection()

    # Test method for ReplicatedDHT.delete(key) and TransactionSingleOp#write(key, value=str()).
    # Inserts some values, tries to delete them afterwards and tries the delete again.
    def testDelete1(self):
        key = "_Delete1"
        c = scalaris.JSONConnection(url = scalaris.DEFAULT_URL)
        rdht = ReplicatedDHT(conn = c)
        sc = scalaris.TransactionSingleOp(conn = c)
        
        for i in xrange(len(_TEST_DATA)):
            sc.write(str(self._testTime) + key + str(i), _TEST_DATA[i])
        
        # now try to delete the data:
        for i in xrange(len(_TEST_DATA)):
            ok = rdht.delete(str(self._testTime) + key + str(i))
            self.assertEqual(ok, 4)
            results = rdht.get_last_delete_result()
            self.assertEqual((results.ok, results.locks_set, results.undefined), (4, 0, 0))
            self._checkKeyDoesNotExist(str(self._testTime) + key + str(i))
            
            # try again (should be successful with 0 deletes)
            ok = rdht.delete(str(self._testTime) + key + str(i))
            self.assertEqual(ok, 0)
            results = rdht.get_last_delete_result()
            self.assertEqual((results.ok, results.locks_set, results.undefined), (0, 0, 4))
            self._checkKeyDoesNotExist(str(self._testTime) + key + str(i))
        
        c.close()

    # Test method for ReplicatedDHT.delete(key) and TransactionSingleOp#write(key, value=str()).
    # Inserts some values, tries to delete them afterwards, inserts them again and tries to delete them again (twice).
    def testDelete2(self):
        key = "_Delete2"
        c = scalaris.JSONConnection(url = scalaris.DEFAULT_URL)
        rdht = ReplicatedDHT(conn = c)
        sc = scalaris.TransactionSingleOp(conn = c)
        
        for i in xrange(len(_TEST_DATA)):
            sc.write(str(self._testTime) + key + str(i), _TEST_DATA[i])
        
        # now try to delete the data:
        for i in xrange(len(_TEST_DATA)):
            ok = rdht.delete(str(self._testTime) + key + str(i))
            self.assertEqual(ok, 4)
            results = rdht.get_last_delete_result()
            self.assertEqual((results.ok, results.locks_set, results.undefined), (4, 0, 0))
            self._checkKeyDoesNotExist(str(self._testTime) + key + str(i))
        
        for i in xrange(len(_TEST_DATA)):
            sc.write(str(self._testTime) + key + str(i), _TEST_DATA[i])
        
        # now try to delete the data:
        for i in xrange(len(_TEST_DATA)):
            ok = rdht.delete(str(self._testTime) + key + str(i))
            self.assertEqual(ok, 4)
            results = rdht.get_last_delete_result()
            self.assertEqual((results.ok, results.locks_set, results.undefined), (4, 0, 0))
            self._checkKeyDoesNotExist(str(self._testTime) + key + str(i))
            
            # try again (should be successful with 0 deletes)
            ok = rdht.delete(str(self._testTime) + key + str(i))
            self.assertEqual(ok, 0)
            results = rdht.get_last_delete_result()
            self.assertEqual((results.ok, results.locks_set, results.undefined), (0, 0, 4))
            self._checkKeyDoesNotExist(str(self._testTime) + key + str(i))
        
        c.close()

if __name__ == "__main__":
    #import sys;sys.argv = ['', 'Test.testName']
    unittest.main()
