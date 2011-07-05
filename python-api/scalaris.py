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

import httplib, urlparse, base64
import os
try: import simplejson as json
except ImportError: import json

if 'SCALARIS_JSON_URL' in os.environ and os.environ['SCALARIS_JSON_URL'] != '':
    DEFAULT_URL = os.environ['SCALARIS_JSON_URL']
else:
    DEFAULT_URL = 'http://localhost:8000'
"""default URL and port to a scalaris node"""
DEFAULT_TIMEOUT = 5
"""socket timeout in seconds"""
DEFAULT_PATH = '/jsonrpc.yaws'
"""path to the json rpc page"""

class JSONConnection(object):
    """
    Abstracts connections to scalaris using JSON
    """
    
    def __init__(self, url = DEFAULT_URL, timeout = DEFAULT_TIMEOUT):
        """
        Creates a JSON connection to the given URL using the given TCP timeout
        """
        try:
            uri = urlparse.urlparse(url)
            self._conn = httplib.HTTPConnection(uri.hostname, uri.port,
                                                timeout = timeout)
        except Exception as instance:
            raise ConnectionError(instance)

    def call(self, function, params):
        """
        Calls the given function with the given parameters via the JSON
        interface of scalaris.
        """
        params = {'jsonrpc': '2.0',
                  'method': function,
                  'params': params,
                  'id': 0}
        try:
            # use compact JSON encoding:
            params_json = json.dumps(params, separators=(',',':'))
            headers = {"Content-type": "application/json; charset=utf-8"}
            # no need to quote - we already encode to json:
            #self._conn.request("POST", DEFAULT_PATH, urllib.quote(params_json), headers)
            self._conn.request("POST", DEFAULT_PATH, params_json, headers)
            response = self._conn.getresponse()
            #print response.status, response.reason
            if (response.status < 200 or response.status >= 300):
                raise ConnectionError(response)
            data = response.read().decode('utf-8')
            response_json = json.loads(data)
            return response_json['result']
        except Exception as instance:
            raise ConnectionError(instance)

    @staticmethod
    def encode_value(value):
        """
        Encodes the value to the form required by the scalaris JSON API
        """
        if isinstance(value, bytearray):
            return {'type': 'as_bin', 'value': (base64.b64encode(value)).decode('ascii')}
        else:
            return {'type': 'as_is', 'value': value}

    @staticmethod
    def decode_value(value):
        """
        Decodes the value from the scalaris JSON API form to a native type
        """
        if ('type' not in value) or ('value' not in value):
            raise UnknownError(value)
        if value['type'] == 'as_bin':
            return bytearray(base64.b64decode(value['value'].encode('ascii')))
        else:
            return value['value']
    
    # result: {'status': 'ok', 'value': xxx} or
    #         {'status': 'fail', 'reason': 'timeout' or 'not_found'}
    @staticmethod
    def process_result_read(result):
        """
        Processes the result of a read operation.
        Returns the read value on success.
        Raises the appropriate exception if the operation failed.
        """
        if isinstance(result, dict) and 'status' in result and len(result) == 2:
            if result['status'] == 'ok' and 'value' in result:
                return JSONConnection.decode_value(result['value'])
            elif result['status'] == 'fail' and 'reason' in result:
                if result['reason'] == 'timeout':
                    raise TimeoutError(result)
                elif result['reason'] == 'not_found':
                    raise NotFoundError(result)
        raise UnknownError(result)
        
    # result: {'status': 'ok'} or
    #         {'status': 'fail', 'reason': 'timeout'}
    @staticmethod
    def process_result_write(result):
        """
        Processes the result of a write operation.
        Raises the appropriate exception if the operation failed.
        """
        if isinstance(result, dict):
            if result == {'status': 'ok'}:
                return None
            elif result == {'status': 'fail', 'reason': 'timeout'}:
                raise TimeoutError(result)
        raise UnknownError(result)
        
    # result: {'status': 'ok'} or
    #         {'status': 'fail', 'reason': 'timeout' or 'abort'}
    @staticmethod
    def process_result_commit(result):
        """
        Processes the result of a commit operation.
        Raises the appropriate exception if the operation failed.
        """
        if isinstance(result, dict) and 'status' in result:
            if result == {'status': 'ok'}:
                return None
            elif result['status'] == 'fail' and 'reason' in result and len(result) == 2:
                if result['reason'] == 'timeout':
                    raise TimeoutError(result)
                elif result['reason'] == 'abort':
                    raise AbortError(result)
        raise UnknownError(result)
        
    # results: {'status': 'ok'} or
    #          {'status': 'fail', 'reason': 'timeout' or 'abort' or 'not_found'} or
    #          {'status': 'fail', 'reason': 'key_changed', 'value': xxx}
    @staticmethod
    def process_result_test_and_set(result):
        """
        Processes the result of a test_and_set operation.
        Raises the appropriate exception if the operation failed.
        """
        if isinstance(result, dict) and 'status' in result:
            if result == {'status': 'ok'}:
                return None
            elif result['status'] == 'fail' and 'reason' in result:
                if len(result) == 2:
                    if result['reason'] == 'timeout':
                        raise TimeoutError(result)
                    elif result['reason'] == 'abort':
                        raise AbortError(result)
                    elif result['reason'] == 'not_found':
                        raise NotFoundError(result)
                elif result['reason'] == 'key_changed' and 'value' in result and len(result) == 3:
                    raise KeyChangedError(result, JSONConnection.decode_value(result['value']))
        raise UnknownError(result)
    
    # results: {'status': 'ok'}
    @staticmethod
    def process_result_publish(result):
        """
        Processes the result of a publish operation.
        Raises the appropriate exception if the operation failed.
        """
        if result == {'status': 'ok'}:
            return None
        raise UnknownError(result)
    
    # results: {'status': 'ok'} or
    #          {'status': 'fail', 'reason': 'timeout' or 'abort'}
    @staticmethod
    def process_result_subscribe(result):
        """
        Processes the result of a subscribe operation.
        Raises the appropriate exception if the operation failed.
        """
        JSONConnection.process_result_commit(result)
    
    # results: {'status': 'ok'} or
    #          {'status': 'fail', 'reason': 'timeout' or 'abort' or 'not_found'}
    @staticmethod
    def process_result_unsubscribe(result):
        """
        Processes the result of a unsubscribe operation.
        Raises the appropriate exception if the operation failed.
        """
        if result == {'status': 'ok'}:
            return None
        elif isinstance(result, dict) and 'status' in result:
            if result['status'] == 'fail' and 'reason' in result and len(result) == 2:
                if result['reason'] == 'timeout':
                    raise TimeoutError(result)
                elif result['reason'] == 'abort':
                    raise AbortError(result)
                elif result['reason'] == 'not_found':
                    raise NotFoundError(result)
        raise UnknownError(result)
    
    # results: [urls=str()]
    @staticmethod
    def process_result_get_subscribers(result):
        """
        Processes the result of a get_subscribers operation.
        Returns the list of subscribers on success.
        Raises the appropriate exception if the operation failed.
        """
        if isinstance(result, list):
            return result
        raise UnknownError(result)

    # results: {'ok': xxx, 'results': ['ok' or 'locks_set' or 'undef']} or
    #          {'failure': 'timeout', 'ok': xxx, 'results': ['ok' or 'locks_set' or 'undef']}
    @staticmethod
    def process_result_delete(result):
        """
        Processes the result of a delete operation.
        Returns the tuple
        (<success (True | 'timeout')>, <number of deleted items>, <detailed results>) on success.
        Raises the appropriate exception if the operation failed.
        """
        if isinstance(result, dict) and 'ok' in result and 'results' in result:
            if 'failure' not in result:
                return (True, result['ok'], result['results'])
            elif result['failure'] == 'timeout':
                return ('timeout', result['ok'], result['results'])
        raise UnknownError(result)
    
    # results: ['ok' or 'locks_set' or 'undef']
    @staticmethod
    def create_delete_result(result):
        """
        Creates a new DeleteResult from the given result list.
        """
        ok = 0
        locks_set = 0
        undefined = 0
        if isinstance(result, list):
            for element in result:
                if element == 'ok':
                    ok += 1
                elif element == 'locks_set':
                    locks_set += 1
                elif element == 'undef':
                    undefined += 1
                else:
                    raise UnknownError('Unknown reason ' + element + 'in ' + result)
            return DeleteResult(ok, locks_set, undefined)
        raise UnknownError('Unknown result ' + result)

    # results: {'tlog': xxx,
    #           'results': [{'status': 'ok'} or {'status': 'ok', 'value': xxx} or
    #                       {'status': 'fail', 'reason': 'timeout' or 'abort' or 'not_found'}]}
    @staticmethod
    def process_result_req_list_t(result):
        """
        Processes the result of a req_list operation of the Transaction class.
        Returns the tuple (<tlog>, <result>) on success.
        Raises the appropriate exception if the operation failed.
        """
        if 'tlog' not in result or 'results' not in result or \
            not isinstance(result['results'], list):
            raise UnknownError(result)
        return (result['tlog'], result['results'])

    # results: [{'status': 'ok'} or {'status': 'ok', 'value': xxx} or
    #           {'status': 'fail', 'reason': 'timeout' or 'abort' or 'not_found'}]
    @staticmethod
    def process_result_req_list_tso(result):
        """
        Processes the result of a req_list operation of the TransactionSingleOp class.
        Returns <result> on success.
        Raises the appropriate exception if the operation failed.
        """
        if not isinstance(result, list):
            raise UnknownError(result)
        return result
    
    # result: 'ok'
    @staticmethod
    def process_result_nop(result):
        """
        Processes the result of a nop operation.
        Raises the appropriate exception if the operation failed.
        """
        if result != 'ok':
            raise UnknownError(result)
    
    @staticmethod
    def new_req_list_t(other = None):
        """
        Returns a new ReqList object allowing multiple parallel requests for
        the Transaction class.
        """
        return _JSONReqListTransaction(other)
    
    @staticmethod
    def new_req_list_tso(other = None):
        """
        Returns a new ReqList object allowing multiple parallel requests for
        the TransactionSingleOp class.
        """
        return _JSONReqListTransactionSingleOp(other)
    
    def close(self):
        self._conn.close()

class ScalarisError(Exception):
    """Base class for errors in the scalaris package."""

class AbortError(ScalarisError):
    """
    Exception that is thrown if a the commit of a write operation on a scalaris
    ring fails.
    """
    
    def __init__(self, raw_result):
        self.raw_result = raw_result
    def __str__(self):
        return repr(self.raw_result)

class ConnectionError(ScalarisError):
    """
    Exception that is thrown if an operation on a scalaris ring fails because
    a connection does not exist or has been disconnected.
    """
    
    def __init__(self, raw_result):
        self.raw_result = raw_result
    def __str__(self):
        return repr(self.raw_result)

class KeyChangedError(ScalarisError):
    """
    Exception that is thrown if a test_and_set operation on a scalaris ring
    fails because the old value did not match the expected value.
    """
    
    def __init__(self, raw_result, old_value):
        self.raw_result = raw_result
        self.old_value = old_value
    def __str__(self):
        return repr(self.raw_result) + ', old value: ' + repr(self.old_value)

class NodeNotFoundError(ScalarisError):
    """
    Exception that is thrown if a delete operation on a scalaris ring fails
    because no scalaris node was found.
    """
    
    def __init__(self, raw_result):
        self.raw_result = raw_result
    def __str__(self):
        return repr(self.raw_result)

class NotFoundError(ScalarisError):
    """
    Exception that is thrown if a read operation on a scalaris ring fails
    because the key did not exist before.
    """
    
    def __init__(self, raw_result):
        self.raw_result = raw_result
    def __str__(self):
        return repr(self.raw_result)

class TimeoutError(ScalarisError):
    """
    Exception that is thrown if a read or write operation on a scalaris ring
    fails due to a timeout.
    """
    
    def __init__(self, raw_result):
        self.raw_result = raw_result
    def __str__(self):
        return repr(self.raw_result)

class UnknownError(ScalarisError):
    """
    Generic exception that is thrown during operations on a scalaris ring, e.g.
    if an unknown result has been returned.
    """
    
    def __init__(self, raw_result):
        self.raw_result = raw_result
    def __str__(self):
        return repr(self.raw_result)

class DeleteResult(object):
    """
    Stores the result of a delete operation.
    """
    def __init__(self, ok, locks_set, undefined):
        self.ok = ok
        self.locks_set = locks_set
        self.undefined = undefined

class TransactionSingleOp(object):
    """
    Single write or read operations on scalaris.
    """
    
    def __init__(self, conn = JSONConnection()):
        """
        Create a new object using the given connection
        """
        self._conn = conn
    
    def new_req_list(self, other = None):
        """
        Returns a new ReqList object allowing multiple parallel requests.
        """
        return self._conn.new_req_list_tso(other)
    
    def req_list(self, reqlist):
        """
        Issues multiple parallel requests to scalaris; each will be committed.
        Request lists can be created using new_req_list().
        The returned list has the following form:
        [{'status': 'ok'} or {'status': 'ok', 'value': xxx} or
        {'status': 'fail', 'reason': 'timeout' or 'abort' or 'not_found'}].
        Elements of this list can be processed with process_result_read() and
        process_result_write().
        """
        result = self._conn.call('req_list_commit_each', [reqlist.get_requests()])
        result = self._conn.process_result_req_list_tso(result)
        return result
    
    def process_result_read(self, result):
        """
        Processes a result element from the list returned by req_list() which
        originated from a read operation.
        Returns the read value on success.
        Raises the appropriate exceptions if a failure occurred during the
        operation.
        Beware: lists of (small) integers may be (falsely) returned as a string -
        use str_to_list() to convert such strings.
        """
        return self._conn.process_result_read(result)

    def process_result_write(self, result):
        """
        Processes a result element from the list returned by req_list() which
        originated from a write operation.
        Raises the appropriate exceptions if a failure occurred during the
        operation.
        """
        # note: we need to process a commit result as the write has been committed
        return self._conn.process_result_commit(result)

    def read(self, key):
        """
        Read the value at key.
        Beware: lists of (small) integers may be (falsely) returned as a string -
        use str_to_list() to convert such strings.
        """
        result = self._conn.call('read', [key])
        return self._conn.process_result_read(result)

    def write(self, key, value):
        """
        Write the value to key.
        """
        value = self._conn.encode_value(value)
        result = self._conn.call('write', [key, value])
        self._conn.process_result_commit(result)
    
    def test_and_set(self, key, oldvalue, newvalue):
        """
        Atomic test and set, i.e. if the old value at key is oldvalue, then
        write newvalue.
        """
        oldvalue = self._conn.encode_value(oldvalue)
        newvalue = self._conn.encode_value(newvalue)
        result = self._conn.call('test_and_set', [key, oldvalue, newvalue])
        self._conn.process_result_test_and_set(result)

    def nop(self, value):
        """
        No operation (may be used for measuring the JSON overhead).
        """
        value = self._conn.encode_value(value)
        result = self._conn.call('nop', [value])
        self._conn.process_result_nop(result)
    
    def close_connection(self):
        """
        Close the connection to scalaris
        (it will automatically be re-opened on the next request).
        """
        self._conn.close()

class Transaction(object):
    """
    Write or read operations on scalaris inside a transaction.
    """
    
    def __init__(self, conn = JSONConnection()):
        """
        Create a new object using the given connection
        """
        self._conn = conn
        self._tlog = None
    
    def new_req_list(self, other = None):
        """
        Returns a new ReqList object allowing multiple parallel requests.
        """
        return self._conn.new_req_list_t(other)
    
    def req_list(self, reqlist):
        """
        Issues multiple parallel requests to scalaris.
        Request lists can be created using new_req_list().
        The returned list has the following form:
        [{'status': 'ok'} or {'status': 'ok', 'value': xxx} or
        {'status': 'fail', 'reason': 'timeout' or 'abort' or 'not_found'}].
        Elements of this list can be processed with process_result_read() and
        process_result_write().
        A commit (at the end of the request list) will be automatically checked
        for its success.
        """
        if self._tlog is None:
            result = self._conn.call('req_list', [reqlist.get_requests()])
        else:
            result = self._conn.call('req_list', [self._tlog, reqlist.get_requests()])
        (tlog, result) = self._conn.process_result_req_list_t(result)
        self._tlog = tlog
        if reqlist.is_commit():
            self._process_result_commit(result[-1])
            # transaction was successful: reset transaction log
            self._tlog = None
        return result
    
    def process_result_read(self, result):
        """
        Processes a result element from the list returned by req_list() which
        originated from a read operation.
        Returns the read value on success.
        Raises the appropriate exceptions if a failure occurred during the
        operation.
        Beware: lists of (small) integers may be (falsely) returned as a string -
        use str_to_list() to convert such strings.
        """
        return self._conn.process_result_read(result)

    def process_result_write(self, result):
        """
        Processes a result element from the list returned by req_list() which
        originated from a write operation.
        Raises the appropriate exceptions if a failure occurred during the
        operation.
        """
        return self._conn.process_result_write(result)

    def _process_result_commit(self, result):
        """
        Processes a result element from the list returned by req_list() which
        originated from a commit operation.
        Raises the appropriate exceptions if a failure occurred during the
        operation.
        """
        return self._conn.process_result_commit(result)
    
    def commit(self):
        """
        Issues a commit operation to scalaris validating the previously
        created operations inside the transaction.
        """
        result = self.req_list(self.new_req_list().add_commit())[0]
        self._process_result_commit(result)
        # reset tlog (minor optimization which is not done in req_list):
        self._tlog = None
    
    def abort(self):
        """
        Aborts all previously created operations inside the transaction.
        """
        self._tlog = None
    
    def read(self, key):
        """
        Issues a read operation to scalaris, adds it to the current
        transaction and returns the result.
        Beware: lists of (small) integers may be (falsely) returned as a string -
        use str_to_list() to convert such strings.
        """
        result = self.req_list(self.new_req_list().add_read(key))[0]
        return self.process_result_read(result)
    
    def write(self, key, value):
        """
        Issues a write operation to scalaris and adds it to the current
        transaction.
        """
        result = self.req_list(self.new_req_list().add_write(key, value))[0]
        self._process_result_commit(result)

    def nop(self, value):
        """
        No operation (may be used for measuring the JSON overhead).
        """
        value = self._conn.encode_value(value)
        result = self._conn.call('nop', [value])
        self._conn.process_result_nop(result)
    
    def close_connection(self):
        """
        Close the connection to scalaris
        (it will automatically be re-opened on the next request).
        """
        self._conn.close()

class _JSONReqList(object):
    """
    Generic request list.
    """
    
    def __init__(self, other = None):
        """
        Create a new object using a JSON connection.
        """
        self._requests = []
        self._is_commit = False
        if other is not None:
            self.extend(other)
    
    def add_read(self, key):
        """
        Adds a read operation to the request list.
        """
        if (self._is_commit):
            raise RuntimeError("No further request supported after a commit!")
        self._requests.append({'read': key})
        return self
    
    def add_write(self, key, value):
        """
        Adds a write operation to the request list.
        """
        if (self._is_commit):
            raise RuntimeError("No further request supported after a commit!")
        self._requests.append({'write': {key: JSONConnection.encode_value(value)}})
        return self
    
    def add_commit(self):
        """
        Adds a commit operation to the request list.
        """
        if (self._is_commit):
            raise RuntimeError("Only one commit per request list allowed!")
        self._requests.append({'commit': ''})
        self._is_commit = True
        return self
    
    def get_requests(self):
        """
        Gets the collected requests.
        """
        return self._requests

    def is_commit(self):
        """
        Returns whether the transactions contains a commit or not.
        """
        return self._is_commit

    def is_empty(self):
        """
        Checks whether the request list is empty.
        """
        return self._requests == []

    def size(self):
        """
        Gets the number of requests in the list.
        """
        return len(self._requests)

    def extend(self, other):
        """
        Adds all requests of the other request list to the end of this list.
        """
        self._requests.extend(other._requests)
        return self

class _JSONReqListTransaction(_JSONReqList):
    """
    Request list for use with Transaction.req_list().
    """
    
    def __init__(self, other = None):
        _JSONReqList.__init__(self, other)

class _JSONReqListTransactionSingleOp(_JSONReqList):
    """
    Request list for use with TransactionSingleOp.req_list() which does not
    support commits.
    """
    
    def __init__(self, other = None):
        _JSONReqList.__init__(self, other)
    
    def add_commit(self):
        """
        Adds a commit operation to the request list.
        """
        raise RuntimeError("No commit allowed in TransactionSingleOp.req_list()!")

class PubSub(object):
    """
    Publish and subscribe methods accessing scalaris' pubsub system
    """
    
    def __init__(self, conn = JSONConnection()):
        """
        Create a new object using the given connection.
        """
        self._conn = conn

    def publish(self, topic, content):
        """
        Publishes content under topic.
        """
        # note: do NOT encode the content, this is not decoded on the erlang side!
        # (only strings are allowed anyway)
        # content = self._conn.encode_value(content)
        result = self._conn.call('publish', [topic, content])
        self._conn.process_result_publish(result)

    def subscribe(self, topic, url):
        """
        Subscribes url for topic.
        """
        # note: do NOT encode the URL, this is not decoded on the erlang side!
        # (only strings are allowed anyway)
        # url = self._conn.encode_value(url)
        result = self._conn.call('subscribe', [topic, url])
        self._conn.process_result_subscribe(result)

    def unsubscribe(self, topic, url):
        """
        Unsubscribes url from topic.
        """
        # note: do NOT encode the URL, this is not decoded on the erlang side!
        # (only strings are allowed anyway)
        # url = self._conn.encode_value(url)
        result = self._conn.call('unsubscribe', [topic, url])
        self._conn.process_result_unsubscribe(result)

    def get_subscribers(self, topic):
        """
        Gets the list of all subscribers to topic.
        """
        result = self._conn.call('get_subscribers', [topic])
        return self._conn.process_result_get_subscribers(result)

    def nop(self, value):
        """
        No operation (may be used for measuring the JSON overhead).
        """
        value = self._conn.encode_value(value)
        result = self._conn.call('nop', [value])
        self._conn.process_result_nop(result)
    
    def close_connection(self):
        """
        Close the connection to scalaris
        (it will automatically be re-opened on the next request).
        """
        self._conn.close()

class ReplicatedDHT(object):
    """
    Non-transactional operations on the replicated DHT of scalaris
    """
    
    def __init__(self, conn = JSONConnection()):
        """
        Create a new object using the given connection.
        """
        self._conn = conn

    # returns the number of successfully deleted items
    # use get_last_delete_result() to get more details
    def delete(self, key, timeout = 2000):
        """
        Tries to delete the value at the given key.
        
        WARNING: This function can lead to inconsistent data (e.g. deleted items
        can re-appear). Also when re-creating an item the version before the
        delete can re-appear.
        """
        result = self._conn.call('delete', [key, timeout])
        (success, ok, results) = self._conn.process_result_delete(result)
        self._lastDeleteResult = results
        if success == True:
            return ok
        elif success == 'timeout':
            raise TimeoutError(result)
        else:
            raise UnknownError(result)

    def get_last_delete_result(self):
        """
        Returns the result of the last call to delete().
        
        NOTE: This function traverses the result list returned by scalaris and
        therefore takes some time to process. It is advised to store the returned
        result object once generated.
        """
        return self._conn.create_delete_result(self._lastDeleteResult)

    def nop(self, value):
        """
        No operation (may be used for measuring the JSON overhead).
        """
        value = self._conn.encode_value(value)
        result = self._conn.call('nop', [value])
        self._conn.process_result_nop(result)
    
    def close_connection(self):
        """
        Close the connection to scalaris
        (it will automatically be re-opened on the next request).
        """
        self._conn.close()

def str_to_list(value):
    """
    Converts a string to a list of integers.
    If the expected value of a read operation is a list, the returned value
    could be (mistakenly) a string if it is a list of integers.
    """
    if (isinstance(value, str) or isinstance(value, unicode)):
        chars = list(value)
        return [ord(char) for char in chars]
    else:
        return value
