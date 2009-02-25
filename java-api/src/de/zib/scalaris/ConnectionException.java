/**
 *  Copyright 2007-2008 Konrad-Zuse-Zentrum für Informationstechnik Berlin
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
package de.zib.scalaris;

import com.ericsson.otp.erlang.OtpErlangException;
import com.ericsson.otp.erlang.OtpErlangObject;

/**
 * Exception that is thrown when a read operation on a scalaris ring fails
 * because the connection is not active or a communication error occurred or an
 * exit signal was received or the remote node sent a message containing an
 * invalid cookie.
 * 
 * @author Nico Kruber, kruber@zib.de
 * @version 2.2
 * @since 2.0
 */
public class ConnectionException extends OtpErlangException {
	/**
	 * class version for serialisation
	 */
	private static final long serialVersionUID = 1L;

	/**
	 * Creates the exception with no message.
	 */
	public ConnectionException() {
	}

	/**
	 * Creates the exception with the given message.
	 * 
	 * @param msg
	 *            message of the exception
	 */
	public ConnectionException(String msg) {
		super(msg);
	}
	
	/**
	 * Creates an exception taking the message of the given throwable.
	 * 
	 * @param e the exception to "re-throw"
	 */
	public ConnectionException(Throwable e) {
		super(e.getMessage());
	}

	/**
	 * Creates an exception including the message of the given erlang object.
	 * 
	 * @param erlValue
	 *            the erlang message to include
	 * 
	 * @since 2.2
	 */
	public ConnectionException(OtpErlangObject erlValue) {
		super("Erlang message: " + erlValue.toString());
	}

	/**
	 * Creates an exception taking the message of the given throwable.
	 * 
	 * @param e
	 *            the exception to "re-throw"
	 * @param erlValue
	 *            the string representation of this erlang value is included
	 *            into the message
	 * 
	 * @since 2.2
	 */
	public ConnectionException(Throwable e, OtpErlangObject erlValue) {
		super(e.getMessage() + ",\n  Erlang message: " + erlValue.toString());
	}
}
