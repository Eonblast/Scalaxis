/**
 *  Copyright 2007-2011 Zuse Institute Berlin
 *
 *   Licensed under the Apache License, Version 2.0 (the "License");
 *   you may not use this file except in compliance with the License.
 *   You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *   Unless required by applicable law or agreed to in writing, software
 *   distributed under the License is distributed on an "AS IS" BASIS,
 *   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *   See the License for the specific language governing permissions and
 *   limitations under the License.
 */
package de.zib.scalaris.examples;

import com.ericsson.otp.erlang.OtpErlangString;

import de.zib.scalaris.AbortException;
import de.zib.scalaris.ConnectionException;
import de.zib.scalaris.NotFoundException;
import de.zib.scalaris.TimeoutException;
import de.zib.scalaris.Transaction;
import de.zib.scalaris.TransactionNotFinishedException;
import de.zib.scalaris.UnknownException;

/**
 * Provides an example for using the <code>read</code> and <code>write</code> methods of
 * the {@link Transaction} class together in one transaction.
 * 
 * @author Nico Kruber, kruber@zib.de
 * @version 2.0
 * @since 2.0
 */
public class TransactionReadWriteExample {
	/**
	 * Implements the following transactions each with the Java type methods and
	 * the erlang (OTP) type methods. The keys and values are given on the
	 * command line as "key1 value1 key2 value2 key3".<br />
	 * If no values are given, the default values
	 * <code>(key1, value1) = ("key1", "value1")</code>,
	 * <code>(key2, value2) = ("key2", "value2")</code> and <code>key3 = "key3"</code> are
	 * used.
	 * 
	 * <h3>Transaction 1:</h3>
	 * <code style="white-space:pre;">
	 *   start();
	 *   
	 *   write(key1, value1);
	 *   write(key2, value2);
	 *   
	 *   result1 = read(key1);
	 *   result2 = read(key2);
	 *   result3 = read(key3);
	 *   
	 *   write(key3, result1 + result2);
	 *   
	 *   result3 = read(key3);
	 *   
	 *   commit();
	 * </code>
	 * 
	 * <h3>Transaction 2:</h3>
	 * <code style="white-space:pre;">
	 *   start();
	 *   write(key1, value1);
	 *   commit();
	 *   
	 *   start();
	 *   write(key1, "WRONG value");
	 *   read(key1);
	 *   abort();
	 *   
	 *   start();
	 *   read(key1);
	 *   commit();
	 * </code>
	 * 
	 * @param args
	 *            command line arguments with the structure "key1 value1 key2
	 *            value2 key3"
	 * @see #Transaction1(String, String, String, String, String)
	 * @see #Transaction2(String, String, String, String, String)
	 */
	public static void main(String[] args) {
		String key1, key2, key3;
		String value1, value2;

		if (args.length != 5) {
			key1 = "key1";
			key2 = "key2";
			key3 = "key3";
			value1 = "value1";
			value2 = "value2";
		} else {
			key1 = args[0];
			key2 = args[2];
			key3 = args[4];
			value1 = args[1];
			value2 = args[3];
		}

		Transaction1(key1, value1, key2, value2, key3);
		Transaction2(key1, value1, key2, value2, key3);
	}

	/**
	 * Implements the following transaction with the Java type methods and the
	 * erlang (OTP) type methods:
	 * 
	 * <p>
	 * <code style="white-space:pre;">
	 *   start();
	 *   
	 *   write(key1, value1);
	 *   write(key2, value2);
	 *   
	 *   result1 = read(key1);
	 *   result2 = read(key2);
	 *   result3 = read(key3);
	 *   
	 *   write(key3, result1 + result2);
	 *   
	 *   result3 = read(key3);
	 *   
	 *   commit();
	 * </code>
	 * </p>
	 * 
	 * @param key1
	 *            key1 used the way described above
	 * @param value1
	 *            value1 used the way described above
	 * @param key2
	 *            key2 used the way described above
	 * @param value2
	 *            value2 used the way described above
	 * @param key3
	 *            key3 used the way described above
	 */
	private static void Transaction1(String key1, String value1, String key2,
			String value2, String key3) {
		String result1 = "";
		String result2 = "";
		@SuppressWarnings("unused")
		String result3 = "";
		System.out.println("Transaction 1 using class `Transaction`:");

		System.out.print("    Initialising Transaction object... ");
		try {
			Transaction transaction = new Transaction();
			System.out.println("done");

			try {
				System.out.print("    Starting transaction... ");
				transaction.start();
				System.out.println("done");
				
				otpWrite(transaction, key1, value1);
				otpWrite(transaction, key2, value2);

				result1 = otpRead(transaction, key1);
				result2 = otpRead(transaction, key2);
				try {
					result3 = otpRead(transaction, key3);
				} catch (NotFoundException e) {
//					System.out.println("    caught not_found for " + key3);
				}

				otpWrite(transaction, key3, result1 + result2);

				result3 = otpRead(transaction, key3);

				System.out.print("    Committing transaction... ");
				transaction.commit();
				System.out.println("done");

				System.out.println();
				System.out.println("    --------------------");
				System.out.println();

				System.out.print("    Starting transaction... ");
				transaction.start();
				System.out.println("done");

				write(transaction, key1, value1);
				write(transaction, key2, value2);

				result1 = read(transaction, key1);
				result2 = read(transaction, key2);
				try {
					result3 = read(transaction, key3);
				} catch (NotFoundException e) {
//                  System.out.println("    caught not_found for " + key3);
				}

				write(transaction, key3, result1 + result2);

				result3 = read(transaction, key3);

				System.out.print("    Committing transaction... ");
				transaction.commit();
				System.out.println("done");
			} catch (TimeoutException e) {
				// read/write operation
				transaction.abort();
				System.out.println("    Transaction aborted due to timeout: "
						+ e.getMessage());
			} catch (NotFoundException e) {
				// read/write operation
				transaction.abort();
				System.out
						.println("    Transaction aborted because elements were not found although they should exist: "
								+ e.getMessage());
			} catch (TransactionNotFinishedException e) {
				// transaction.start()
				System.out.println("failed: " + e.getMessage());
            } catch (AbortException e) {
                System.out.println("    Transaction aborted during commit: "
                        + e.getMessage());
			} catch (UnknownException e) {
				// any operation
				System.out.println("failed: " + e.getMessage());
            }

		} catch (ConnectionException e) {
			System.out.println("failed: " + e.getMessage());
		}
		System.out.println("End Transaction 1");
	}

	/**
	 * Implements the following transaction with the Java type methods and the
	 * erlang (OTP) type methods:
	 * 
	 * <p>
	 * <code style="white-space:pre;">
	 *   start();
	 *   write(key1, value1);
	 *   commit();
	 *   
	 *   start();
	 *   write(key1, "WRONG value");
	 *   read(key1);
	 *   abort();
	 *   
	 *   start();
	 *   read(key1);
	 *   commit();
	 * </code>
	 * </p>
	 * 
	 * @param key1
	 *            key1 used the way described above
	 * @param value1
	 *            value1 used the way described above
	 * @param key2
	 *            key2 used the way described above
	 * @param value2
	 *            value2 used the way described above
	 * @param key3
	 *            key3 used the way described above
	 */
	private static void Transaction2(String key1, String value1, String key2,
			String value2, String key3) {
		System.out.println("Transaction 2 using class `Transaction`:");

		System.out.print("    Initialising Transaction object... ");
		try {
			Transaction transaction = new Transaction();
			System.out.println("done");

			try {
				System.out.print("    Starting transaction... ");
				transaction.start();
				System.out.println("done");
				
				otpWrite(transaction, key1, value1);

				System.out.print("    Committing transaction... ");
				transaction.commit();
				System.out.println("done");

				System.out.print("    Starting transaction... ");
				transaction.start();
				System.out.println("done");

				otpWrite(transaction, key1, "WRONG value");
				otpRead(transaction, key1);

				System.out.print("    Aborting transaction... ");
				transaction.abort();
				System.out.println("done");

				System.out.print("    Starting transaction... ");
				transaction.start();
				System.out.println("done");

				otpRead(transaction, key1);

				System.out.print("    Committing transaction... ");
				transaction.commit();
				System.out.println("done");

				System.out.println();
				System.out.println("    --------------------");
				System.out.println();

				System.out.print("    Starting transaction... ");
				transaction.start();
				System.out.println("done");

				write(transaction, key1, value1);

				System.out.print("    Committing transaction... ");
				transaction.commit();
				System.out.println("done");

				System.out.print("    Starting transaction... ");
				transaction.start();
				System.out.println("done");

				write(transaction, key1, "WRONG value");
				read(transaction, key1);

				System.out.print("    Aborting transaction... ");
				transaction.abort();
				System.out.println("done");

				System.out.print("    Starting transaction... ");
				transaction.start();
				System.out.println("done");

				read(transaction, key1);

				System.out.print("    Committing transaction... ");
				transaction.commit();
				System.out.println("done");

			} catch (TimeoutException e) {
				// read/write operation
				transaction.abort();
				System.out.println("    Transaction aborted due to timeout: "
						+ e.getMessage());
			} catch (NotFoundException e) {
				// read/write operation
				transaction.abort();
				System.out
						.println("    Transaction aborted because elements were not found although they should exist: "
								+ e.getMessage());
			} catch (TransactionNotFinishedException e) {
				// transaction.start()
				System.out.println("failed: " + e.getMessage());
            } catch (AbortException e) {
                System.out.println("    Transaction aborted during commit: "
                        + e.getMessage());
			} catch (UnknownException e) {
				// any operation
				System.out.println("failed: " + e.getMessage());
			}

		} catch (ConnectionException e) {
			System.out.println("failed: " + e.getMessage());
		}
		System.out.println("End Transaction 2");
	}

	/**
	 * Writes the given <code>key</code> and <code>value</code> with the
	 * {@link Transaction#writeObject(OtpErlangString, OtpErlangObject)} method on the
	 * given <code>transaction</code> object and generates output according to the
	 * result.
	 * 
	 * @param transaction
	 *            the transaction object to operate on
	 * @param key
	 *            the key to store the value under
	 * @param value
	 *            the value to store
	 * @throws ConnectionException
	 *             if the connection is not active or a communication error
	 *             occurs or an exit signal was received or the remote node
	 *             sends a message containing an invalid cookie
	 * @throws TimeoutException
	 *             if a timeout occurred while trying to write the value
	 * @throws UnknownException
	 *             if any other error occurs
	 */
	private static void otpWrite(Transaction transaction, String key,
			String value) throws ConnectionException, TimeoutException,
			UnknownException {
		System.out.println("    `write(OtpErlangString, OtpErlangString)`...");
		OtpErlangString otpKey = new OtpErlangString(key);
		OtpErlangString otpValue = new OtpErlangString(value);
		try {
			transaction.writeObject(otpKey, otpValue);
			System.out.println("      write(" + otpKey.stringValue() + ", "
					+ otpValue.stringValue() + ") succeeded");
		} catch (ConnectionException e) {
			System.out.println("      write(" + otpKey.stringValue() + ", "
					+ otpValue.stringValue() + ") failed: " + e.getMessage());
			throw new ConnectionException(e);
		} catch (TimeoutException e) {
			System.out.println("      write(" + otpKey.stringValue() + ", "
					+ otpValue.stringValue() + ") failed with timeout: "
					+ e.getMessage());
			throw new TimeoutException(e);
		} catch (UnknownException e) {
			System.out.println("      write(" + otpKey.stringValue() + ", "
					+ otpValue.stringValue() + ") failed with unknown: "
					+ e.getMessage());
			throw new UnknownException(e);
		}
	}

	/**
	 * Writes the given <code>key</code> and <code>value</code> with the
	 * {@link Transaction#write(String, String)} method on the given
	 * <code>transaction</code> object and generates output according to the result.
	 * 
	 * @param transaction
	 *            the transaction object to operate on
	 * @param key
	 *            the key to store the value under
	 * @param value
	 *            the value to store
	 * @throws ConnectionException
	 *             if the connection is not active or a communication error
	 *             occurs or an exit signal was received or the remote node
	 *             sends a message containing an invalid cookie
	 * @throws TimeoutException
	 *             if a timeout occurred while trying to write the value
	 * @throws UnknownException
	 *             if any other error occurs
	 */
	private static void write(Transaction transaction, String key, String value)
			throws ConnectionException, TimeoutException, UnknownException {
		System.out.println("    `write(String, String)`...");
		try {
			transaction.write(key, value);
			System.out.println("      write(" + key + ", " + value
					+ ") succeeded");
		} catch (ConnectionException e) {
			System.out.println("      write(" + key + ", " + value
					+ ") failed: " + e.getMessage());
			throw new ConnectionException(e);
		} catch (TimeoutException e) {
			System.out.println("      write(" + key + ", " + value
					+ ") failed with timeout: " + e.getMessage());
			throw new TimeoutException(e);
		} catch (UnknownException e) {
			System.out.println("      write(" + key + ", " + value
					+ ") failed with unknown: " + e.getMessage());
			throw new UnknownException(e);
		}
	}

	/**
	 * Reads the given <code>key</code> with the
	 * {@link Transaction#readObject(OtpErlangString)} method on the given
	 * <code>transaction</code> object and generates output according to the result.
	 * 
	 * @param transaction
	 *            the transaction object to operate on
	 * @param key
	 *            the key to store the value under
	 * @return the value read from scalaris
	 * @throws ConnectionException
	 *             if the connection is not active or a communication error
	 *             occurs or an exit signal was received or the remote node
	 *             sends a message containing an invalid cookie
	 * @throws TimeoutException
	 *             if a timeout occurred while trying to fetch the value
	 * @throws NotFoundException
	 *             if the requested key does not exist
	 * @throws UnknownException
	 *             if any other error occurs
	 */
	private static String otpRead(Transaction transaction, String key)
			throws ConnectionException, TimeoutException, UnknownException,
			NotFoundException {
		System.out.println("    `OtpErlangString read(OtpErlangString)`...");
		OtpErlangString otpKey = new OtpErlangString(key);
		OtpErlangString otpValue;
		try {
			otpValue = (OtpErlangString) transaction.readObject(otpKey);
			System.out.println("      read(" + otpKey.stringValue() + ") == "
					+ otpValue.stringValue());
			return otpValue.stringValue();
		} catch (ConnectionException e) {
			System.out.println("      read(" + otpKey.stringValue()
					+ ") failed: " + e.getMessage());
			throw new ConnectionException(e);
		} catch (TimeoutException e) {
			System.out.println("      read(" + otpKey.stringValue()
					+ ") failed with timeout: " + e.getMessage());
			throw new TimeoutException(e);
		} catch (UnknownException e) {
			System.out.println("      read(" + otpKey.stringValue()
					+ ") failed with unknown: " + e.getMessage());
			throw new UnknownException(e);
		} catch (NotFoundException e) {
			System.out.println("      read(" + otpKey.stringValue()
					+ ") failed with not found: " + e.getMessage());
			throw new NotFoundException(e);
		} catch (ClassCastException e) {
			System.out.println("      read(" + otpKey.stringValue()
					+ ") failed with unknown return type: " + e.getMessage());
			throw new UnknownException(e);
		}
	}

	/**
	 * Reads the given <code>key</code> with the {@link Transaction#read(String)}
	 * method on the given <code>transaction</code> object and generates output
	 * according to the result.
	 * 
	 * @param transaction
	 *            the transaction object to operate on
	 * @param key
	 *            the key to store the value under
	 * @return the value read from scalaris
	 * @throws ConnectionException
	 *             if the connection is not active or a communication error
	 *             occurs or an exit signal was received or the remote node
	 *             sends a message containing an invalid cookie
	 * @throws TimeoutException
	 *             if a timeout occurred while trying to fetch the value
	 * @throws NotFoundException
	 *             if the requested key does not exist
	 * @throws UnknownException
	 *             if any other error occurs
	 */
	private static String read(Transaction transaction, String key)
			throws ConnectionException, TimeoutException, UnknownException,
			NotFoundException {
		System.out.println("    `String read(String)`...");
		String value;
		try {
			value = transaction.read(key);
			System.out.println("      read(" + key + ") == " + value);
			return value;
		} catch (ConnectionException e) {
			System.out.println("      read(" + key + ") failed: "
					+ e.getMessage());
			throw new ConnectionException(e);
		} catch (TimeoutException e) {
			System.out.println("      read(" + key + ") failed with timeout: "
					+ e.getMessage());
			throw new TimeoutException(e);
		} catch (UnknownException e) {
			System.out.println("      read(" + key + ") failed with unknown: "
					+ e.getMessage());
			throw new UnknownException(e);
		} catch (NotFoundException e) {
			System.out.println("      read(" + key
					+ ") failed with not found: " + e.getMessage());
			throw new NotFoundException(e);
		}
	}
}
