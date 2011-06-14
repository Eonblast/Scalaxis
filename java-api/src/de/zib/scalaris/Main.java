/*
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
package de.zib.scalaris;

import java.util.HashSet;
import java.util.List;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.GnuParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.OptionGroup;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;

/**
 * Class to test basic functionality of the package and to use scalaris
 * from command line.
 *
 * @author Nico Kruber, kruber@zib.de
 * @version 2.0
 * @since 2.0
 */
public class Main {
    /**
     * Queries the command line options for an action to perform.
     *
     * <pre>
     * <code>
     * > java -jar scalaris.jar -help
     * usage: scalaris [Options]
     *  -h,--help                        print this message
     *  -v,--verbose                     print verbose information, e.g. the
     *                                   properties read
     *  -lh,--localhost                  gets the local host's name as known to
     *                                   Java (for debugging purposes)
     *  -b,--minibench                   run mini benchmark
     *  -r,--read <key>                  read an item
     *  -w,--write <key> <value>         write an item
     *  -d,--delete <key> <[timeout]>    delete an item (default timeout: 2000ms)
     *                                   WARNING: This function can lead to
     *                                   inconsistent data (e.g. deleted items
     *                                   can re-appear). Also when re-creating an
     *                                   item the version before the delete can
     *                                   re-appear.
     *  -p,--publish <topic> <message>   publish a new message for the given
     *                                   topic
     *  -s,--subscribe <topic> <url>     subscribe to a topic
     *  -g,--getsubscribers <topic>      get subscribers of a topic
     *  -u,--unsubscribe <topic> <url>   unsubscribe from a topic
     * </code>
     * </pre>
     *
     * In order to override node and cookie to use for a connection, specify
     * the <tt>scalaris.node</tt> or <tt>scalaris.cookie</tt> system properties.
     * Their values will be used instead of the values defined in the config
     * file!
     *
     * @param args
     *            command line arguments
     */
    public static void main(final String[] args) {
        boolean verbose = false;
        final CommandLineParser parser = new GnuParser();
        CommandLine line = null;
        final Options options = getOptions();
        try {
            line = parser.parse(options, args);
        } catch (final ParseException e) {
            printException("Parsing failed", e, false);
        }

        if (line.hasOption("verbose")) {
            verbose = true;
            ConnectionFactory.getInstance().printProperties();
        }

        if (line.hasOption("minibench")) {
            final String[] optionValues = line.getOptionValues("minibench");
            int testruns = 100;
            final HashSet<Integer> benchmarks = new HashSet<Integer>(10);
            if (optionValues != null) {
                checkArguments(optionValues, 2, options, "b");
                testruns = Integer.parseInt(optionValues[0]);
                for (int i = 1; i < Math.min(10, optionValues.length); ++i) {
                    final String benchmarks_str = optionValues[i];
                    if (benchmarks_str.equals("all")) {
                        for (int j = 1; j <= 9; ++j) {
                            benchmarks.add(j);
                        }
                    } else {
                        benchmarks.add(Integer.parseInt(benchmarks_str));
                    }
                }
            } else {
                for (int i = 1; i <= 9; ++i) {
                    benchmarks.add(i);
                }
            }
            Benchmark.minibench(testruns, benchmarks);
        } else if (line.hasOption("r")) { // read
            final String key = line.getOptionValue("read");
            checkArguments(key, options, "r");
            try {
                final TransactionSingleOp sc = new TransactionSingleOp();
                final String value = sc.read(key).value().toString();
                System.out.println("read(" + key + ") == " + value);
            } catch (final ConnectionException e) {
                printException("read failed with connection error", e, verbose);
            } catch (final TimeoutException e) {
                printException("read failed with timeout", e, verbose);
            } catch (final NotFoundException e) {
                printException("read failed with not found", e, verbose);
            } catch (final UnknownException e) {
                printException("read failed with unknown", e, verbose);
            }
        } else if (line.hasOption("w")) { // write
            final String[] optionValues = line.getOptionValues("write");
            checkArguments(optionValues, 2, options, "w");
            final String key = optionValues[0];
            final String value = optionValues[1];
            try {
                final TransactionSingleOp sc = new TransactionSingleOp();
                sc.write(key, value);
                System.out.println("write(" + key + ", " + value + "): ok");
            } catch (final ConnectionException e) {
                printException("write failed with connection error", e, verbose);
            } catch (final TimeoutException e) {
                printException("write failed with timeout", e, verbose);
            } catch (final AbortException e) {
                printException("write failed with abort", e, verbose);
            } catch (final UnknownException e) {
                printException("write failed with unknown", e, verbose);
            }
        } else if (line.hasOption("p")) { // publish
            final String[] optionValues = line.getOptionValues("publish");
            checkArguments(optionValues, 2, options, "p");
            final String topic = optionValues[0];
            final String content = optionValues[1];
            if (content == null) {
                // parsing methods of commons.cli only checks the first argument :(
                printException("Parsing failed", new ParseException("missing content for option p"), verbose);
            }
            try {
                final PubSub sc = new PubSub();
                sc.publish(topic, content);
                System.out.println("publish(" + topic + ", " + content + "): ok");
            } catch (final ConnectionException e) {
                printException("publish failed with connection error", e, verbose);
            } catch (final UnknownException e) {
                printException("publish failed with unknown", e, verbose);
            }
        } else if (line.hasOption("s")) { // subscribe
            final String[] optionValues = line.getOptionValues("subscribe");
            checkArguments(optionValues, 2, options, "s");
            final String topic = optionValues[0];
            final String url = optionValues[1];
            try {
                final PubSub sc = new PubSub();
                sc.subscribe(topic, url);
                System.out.println("subscribe(" + topic + ", " + url + "): ok");
            } catch (final ConnectionException e) {
                printException("subscribe failed with connection error", e, verbose);
            } catch (final TimeoutException e) {
                printException("subscribe failed with timeout", e, verbose);
            } catch (final AbortException e) {
                printException("write failed with abort", e, verbose);
            } catch (final UnknownException e) {
                printException("subscribe failed with unknown", e, verbose);
            }
        } else if (line.hasOption("u")) { // unsubscribe
            final String[] optionValues = line.getOptionValues("unsubscribe");
            checkArguments(optionValues, 2, options, "u");
            final String topic = optionValues[0];
            final String url = optionValues[1];
            try {
                final PubSub sc = new PubSub();
                sc.unsubscribe(topic, url);
                System.out.println("unsubscribe(" + topic + ", " + url + "): ok");
            } catch (final ConnectionException e) {
                printException("unsubscribe failed with connection error", e, verbose);
            } catch (final TimeoutException e) {
                printException("unsubscribe failed with timeout", e, verbose);
            } catch (final NotFoundException e) {
                printException("unsubscribe failed with not found", e, verbose);
            } catch (final AbortException e) {
                printException("write failed with abort", e, verbose);
            } catch (final UnknownException e) {
                printException("unsubscribe failed with unknown", e, verbose);
            }
        } else if (line.hasOption("g")) { // getsubscribers
            final String topic = line.getOptionValue("getsubscribers");
            checkArguments(topic, options, "g");
            try {
                final PubSub sc = new PubSub();
                final List<String> subscribers = sc.getSubscribers(topic).stringListValue();
                System.out.println("getSubscribers(" + topic + ") == "
                        + subscribers);
            } catch (final ConnectionException e) {
                printException("getSubscribers failed with connection error", e, verbose);
            } catch (final UnknownException e) {
                printException("getSubscribers failed with unknown error", e, verbose);
            }
        } else if (line.hasOption("d")) { // delete
            final String[] optionValues = line.getOptionValues("delete");
            checkArguments(optionValues, 1, options, "d");
            final String key = optionValues[0];
            int timeout = 2000;
            if (optionValues.length >= 2) {
                try {
                    timeout = Integer.parseInt(optionValues[1]);
                } catch (final Exception e) {
                    printException("Parsing failed", new ParseException(
                            "wrong type for timeout parameter of option d"
                                    + " (parameters: <"
                                    + options.getOption("d").getArgName()
                                    + ">)"), verbose);
                }
            }
            try {
                final ReplicatedDHT sc = new ReplicatedDHT();
                sc.delete(key, timeout);
                final DeleteResult deleteResult = sc.getLastDeleteResult();
                System.out.println("delete(" + key + ", " + timeout + "): "
                        + deleteResult.ok + " ok, "
                        + deleteResult.locks_set + " locks_set, "
                        + deleteResult.undef + " undef");
            } catch (final ConnectionException e) {
                printException("delete failed with connection error", e, verbose);
            } catch (final TimeoutException e) {
                printException("delete failed with timeout", e, verbose);
            } catch (final UnknownException e) {
                printException("delete failed with unknown error", e, verbose);
            }
        } else if (line.hasOption("lh")) { // get local host name
            System.out.println(ConnectionFactory.getLocalhostName());
        } else {
            // print help if no other option was given
//        if (line.hasOption("help")) {
            final HelpFormatter formatter = new HelpFormatter();
            formatter.printHelp("scalaris [Options]", getOptions());
        }
    }

    /**
     * Creates the options the command line should understand.
     *
     * @return the options the program understands
     */
    private static Options getOptions() {
        final Options options = new Options();
        final OptionGroup group = new OptionGroup();

        /* Note: arguments are set to be optional since we implement argument
         * checks on our own (commons.cli is not flexible enough and only
         * checks for the existence of a first argument)
         */

        options.addOption(new Option("h", "help", false, "print this message"));

        options.addOption(new Option("v", "verbose", false, "print verbose information, e.g. the properties read"));

        final Option read = new Option("r", "read", true, "read an item");
        read.setArgName("key");
        read.setArgs(1);
        read.setOptionalArg(true);
        group.addOption(read);

        final Option write = new Option("w", "write", true, "write an item");
        write.setArgName("key> <value");
        write.setArgs(2);
        write.setOptionalArg(true);
        group.addOption(write);

        final Option publish = new Option("p", "publish", true, "publish a new message for the given topic");
        publish.setArgName("topic> <message");
        publish.setArgs(2);
        publish.setOptionalArg(true);
        group.addOption(publish);

        final Option subscribe = new Option("s", "subscribe", true, "subscribe to a topic");
        subscribe.setArgName("topic> <url");
        subscribe.setArgs(2);
        subscribe.setOptionalArg(true);
        group.addOption(subscribe);

        final Option unsubscribe = new Option("u", "unsubscribe", true, "unsubscribe from a topic");
        unsubscribe.setArgName("topic> <url");
        unsubscribe.setArgs(2);
        unsubscribe.setOptionalArg(true);
        group.addOption(unsubscribe);

        final Option getSubscribers = new Option("g", "getsubscribers", true, "get subscribers of a topic");
        getSubscribers.setArgName("topic");
        getSubscribers.setArgs(1);
        getSubscribers.setOptionalArg(true);
        group.addOption(getSubscribers);

        final Option delete = new Option("d", "delete", true,
                "delete an item (default timeout: 2000ms)\n" +
                "WARNING: This function can lead to inconsistent data (e.g. " +
                "deleted items can re-appear). Also when re-creating an item " +
                "the version before the delete can re-appear.");
        delete.setArgName("key> <[timeout]");
        delete.setArgs(2);
        delete.setOptionalArg(true);
        group.addOption(delete);

        final Option bench = new Option("b", "minibench", true, "run selected mini benchmark(s) [1|...|9|all] (default: all benchmarks, 100 test runs)");
        bench.setArgName("runs> <benchmarks");
        bench.setArgs(10);
        bench.setOptionalArg(true);
        group.addOption(bench);

        options.addOptionGroup(group);

        options.addOption(new Option("lh", "localhost", false, "gets the local host's name as known to Java (for debugging purposes)"));

        return options;
    }

    /**
     * Prints the given exception with the given description and terminates the
     * JVM.
     *
     * @param description  will be prepended to the error message
     * @param e            the exception to print
     * @param verbose      specifies whether to include the stack trace or not
     */
    final static void printException(final String description, final ParseException e, final boolean verbose) {
        printException(description, e, verbose, 1);
    }

    /**
     * Prints the given exception with the given description and terminates the
     * JVM.
     *
     * @param description  will be prepended to the error message
     * @param e            the exception to print
     * @param verbose      specifies whether to include the stack trace or not
     */
    final static void printException(final String description, final ConnectionException e, final boolean verbose) {
        printException(description, e, verbose, 2);
    }

    /**
     * Prints the given exception with the given description and terminates the
     * JVM.
     *
     * @param description  will be prepended to the error message
     * @param e            the exception to print
     * @param verbose      specifies whether to include the stack trace or not
     */
    final static void printException(final String description, final TimeoutException e, final boolean verbose) {
        printException(description, e, verbose, 3);
    }

    /**
     * Prints the given exception with the given description and terminates the
     * JVM.
     *
     * @param description  will be prepended to the error message
     * @param e            the exception to print
     * @param verbose      specifies whether to include the stack trace or not
     */
    final static void printException(final String description, final NotFoundException e, final boolean verbose) {
        printException(description, e, verbose, 4);
    }

    /**
     * Prints the given exception with the given description and terminates the
     * JVM.
     *
     * @param description  will be prepended to the error message
     * @param e            the exception to print
     * @param verbose      specifies whether to include the stack trace or not
     */
    final static void printException(final String description, final UnknownException e, final boolean verbose) {
        printException(description, e, verbose, 5);
    }

    /**
     * Prints the given exception with the given description and terminates the
     * JVM.
     *
     * @param description  will be prepended to the error message
     * @param e            the exception to print
     * @param verbose      specifies whether to include the stack trace or not
     */
    final static void printException(final String description, final AbortException e, final boolean verbose) {
        printException(description, e, verbose, 7);
    }

    /**
     * Prints the given exception with the given description and terminates the
     * JVM.
     *
     * Note: exit status 6 was used by the NodeNotFoundException which is not
     * needed anymore - do not re-use this exit status!
     *
     * @param description  will be prepended to the error message
     * @param e            the exception to print
     * @param verbose      specifies whether to include the stack trace or not
     * @param exitStatus   the status code the JVM exits with
     */
    final static void printException(final String description, final Exception e, final boolean verbose, final int exitStatus) {
        System.err.print(description + ": ");
        if (verbose) {
            System.err.println();
            e.printStackTrace();
        } else {
            System.err.println(e.getMessage());
        }
        System.exit(exitStatus);
    }

    /**
     * Checks that the given option value as returned from e.g.
     * {@link CommandLine#getOptionValue(String)} does exist and prints an error
     * message if not.
     *
     * @param optionValue    the value to check
     * @param options        the available command line options
     * @param currentOption  the short name of the current option being parsed
     */
    final static void checkArguments(final String optionValue,
            final Options options, final String currentOption) {
        if (optionValue == null) {
            printException("Parsing failed", new ParseException(
                    "missing parameter for option " + currentOption
                            + " (required: <"
                            + options.getOption(currentOption).getArgName()
                            + ">)"), false);
        }
    }

    /**
     * Checks that the given option values as returned from e.g.
     * {@link CommandLine#getOptionValues(String)} do exist and contain
     * enough parameters. Prints an error message if not.
     *
     * @param optionValues   the values to check
     * @param required       the number of required parameters
     * @param options        the available command line options
     * @param currentOption  the short name of the current option being parsed
     */
    final static void checkArguments(final String[] optionValues,
            final int required, final Options options, final String currentOption) {
        if ((optionValues == null) || (optionValues.length < required)) {
            printException("Parsing failed", new ParseException(
                    "missing parameter for option " + currentOption
                            + " (required: <"
                            + options.getOption(currentOption).getArgName()
                            + ">)"), false);
        }
    }
}
