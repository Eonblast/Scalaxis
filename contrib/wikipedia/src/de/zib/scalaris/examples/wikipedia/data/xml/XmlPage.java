/**
 *  Copyright 2011 Zuse Institute Berlin
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
package de.zib.scalaris.examples.wikipedia.data.xml;

import java.util.Calendar;
import java.util.LinkedHashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.TreeMap;

import org.xml.sax.Attributes;
import org.xml.sax.helpers.DefaultHandler;

import de.zib.scalaris.examples.wikipedia.data.Page;
import de.zib.scalaris.examples.wikipedia.data.Revision;

/**
 * Represents a page including its revisions for use by an XML reader.
 * 
 * @author Nico Kruber, kruber@zib.de
 */
public class XmlPage extends DefaultHandler {
    protected StringBuilder currentString = new StringBuilder();
    /**
     * The page's title.
     */
    protected String title;

    /**
     * The page's ID.
     */
    protected String id;

    /**
     * The page's restrictions, e.g. for moving/editing the page.
     */
    protected String restrictions;
    
    /**
     * Whether the page's newest revision redirects or not.
     */
    protected boolean redirect;
    
    /**
     * All revisions of the page.
     */
    protected TreeMap<Integer, Revision> revisions = new TreeMap<Integer, Revision>();
    
    protected boolean inPage_title;
    protected boolean inPage_id;
    protected boolean inPage_restrictions;
    protected boolean inRevision;
    
    protected XmlRevision currentRevision = new XmlRevision();
    
    protected Page final_page;

    /**
     * Maximum number of revisions per page (starting with the most recent) -
     * <tt>-1/tt> imports all revisions.
     */
    protected int maxRevisions;
    
    /**
     * Maximum time a revision should have (newer revisions are omitted) -
     * <tt>null/tt> imports all revisions.
     */
    protected Calendar maxTime;

    /**
     * Creates a new page with an empty title, id and no revision.
     * 
     * @param maxRevisions
     *            maximum number of revisions per page (starting with the most
     *            recent) - <tt>-1/tt> imports all revisions
     * @param maxTime
     *            maximum time a revision should have (newer revisions are
     *            omitted) - <tt>null/tt> imports all revisions
     */
    public XmlPage(int maxRevisions, Calendar maxTime) {
        super();
        this.maxRevisions = maxRevisions;
        this.maxTime = maxTime;
        init();
    }
    
    /**
     * (Re-) Initialises all instance variables.
     */
    private void init() {
        currentString.setLength(0);
        title = "";
        id = "";
        restrictions = "";
        redirect = false;
        revisions.clear();
        inPage_title = false;
        inPage_id = false;
        inPage_restrictions = false;
        inRevision = false;
        currentRevision.reset();
        final_page = null;
    }
    
    /**
     * Resets all instance variables. Afterwards, the object has the same state
     * as a newly created one with the given {@link #maxRevisions} and
     * {@link #maxTime}.
     */
    public void reset() {
        init();
    }

    /**
     * Called to when a starting page element is encountered.
     * 
     * @param uri
     *            The Namespace URI, or the empty string if the element has no
     *            Namespace URI or if Namespace processing is not being
     *            performed.
     * @param localName
     *            The local name (without prefix), or the empty string if
     *            Namespace processing is not being performed.
     * @param qName
     *            The qualified name (with prefix), or the empty string if
     *            qualified names are not available.
     * @param attributes
     *            The attributes attached to the element. If there are no
     *            attributes, it shall be an empty Attributes object.
     */
    public void startPage(String uri, String localName, String qName,
            Attributes attributes) {
        // nothing to do
    }       

    /**
     * Called to when a starting element is encountered.
     * 
     * @param uri
     *            The Namespace URI, or the empty string if the element has no
     *            Namespace URI or if Namespace processing is not being
     *            performed.
     * @param localName
     *            The local name (without prefix), or the empty string if
     *            Namespace processing is not being performed.
     * @param qName
     *            The qualified name (with prefix), or the empty string if
     *            qualified names are not available.
     * @param attributes
     *            The attributes attached to the element. If there are no
     *            attributes, it shall be an empty Attributes object.
     */
    @Override
    public void startElement(String uri, String localName, String qName,
            Attributes attributes) {
        // System.out.println(localName);
        
        if (inRevision) {
            currentRevision.startElement(uri, localName, qName, attributes);
        } else {
            currentString.setLength(0);
            /*
             * <title>Main Page</title> <id>1</id> <revision></revision> ...
             */
            if (localName.equals("title")) {
            } else if (localName.equals("id")) {
            } else if (localName.equals("restrictions")) {
            } else if (localName.equals("redirect")) {
                redirect = true;
            } else if (localName.equals("revision")) {
                inRevision = true;
                currentRevision.reset();
                currentRevision.startRevision(uri, localName, qName, attributes);
            } else {
                System.err.println("unknown page tag: " + localName);
            }
        }
    }

    /**
     * Called to process character data.
     * 
     * Note: a SAX driver is free to chunk the character data any way it wants,
     * so you cannot count on all of the character data content of an element
     * arriving in a single characters event.
     * 
     * @param ch
     *            The characters.
     * @param start
     *            The start position in the character array.
     * @param length
     *            The number of characters to use from the character array.
     */
    @Override
    public void characters(char[] ch, int start, int length) {
        // System.out.println(new String(ch, start, length));

        if (inRevision) {
            currentRevision.characters(ch, start, length);
        } else {
            currentString.append(ch, start, length);
        }

    }

    /**
     * Called to when an ending element is encountered.
     * 
     * @param uri
     *            The Namespace URI, or the empty string if the element has no
     *            Namespace URI or if Namespace processing is not being
     *            performed.
     * @param localName
     *            The local name (without prefix), or the empty string if
     *            Namespace processing is not being performed.
     * @param qName
     *            The qualified name (with prefix), or the empty string if
     *            qualified names are not available.
     */
    public void endPage(String uri, String localName, String qName) {
        /* 
         * parse page restrictions - examples:
         * <restrictions>edit=sysop:move=sysop</restrictions>
         * <restrictions>sysop</restrictions>
         */
        LinkedHashMap<String, String> restrictions_map = new LinkedHashMap<String, String>();
        if (!restrictions.isEmpty()) {
            String[] restrictions_array = restrictions.split(":");
            for (int i = 0; i < restrictions_array.length; ++i) {
                String[] restriction = restrictions_array[i].split("=");
                if (restriction.length == 2) {
                    restrictions_map.put(restriction[0], restriction[1]);
                } else if (restriction.length == 1) {
                    restrictions_map.put("all", restriction[0]);
                } else {
                    System.err.println("Unknown restriction: " + restrictions_array[i]);
                }
            }
        }
        // get current revision (the largest one):
        Revision curRev = null;
        if (!revisions.isEmpty()) {
            curRev = revisions.lastEntry().getValue();
        }
        final_page = new Page(title,
                Integer.parseInt(id), redirect, restrictions_map, curRev);
    }

    /**
     * Called to when an ending element is encountered.
     * 
     * @param uri
     *            The Namespace URI, or the empty string if the element has no
     *            Namespace URI or if Namespace processing is not being
     *            performed.
     * @param localName
     *            The local name (without prefix), or the empty string if
     *            Namespace processing is not being performed.
     * @param qName
     *            The qualified name (with prefix), or the empty string if
     *            qualified names are not available.
     */
    @Override
    public void endElement(String uri, String localName, String qName) {
        if (inRevision) {
            if (localName.equals("revision")) {
                inRevision = false;
                currentRevision.endRevision(uri, localName, qName);
                Revision curRev = currentRevision.getRevision();
                if (maxTime == null ||
                        !Revision.stringToCalendar(curRev.getTimestamp()).after(maxTime)) {
                    revisions.put(curRev.getId(), curRev);
                    if (maxRevisions != (-1) && revisions.size() > maxRevisions) {
                        revisions.remove(revisions.firstKey());
                    }
                }
            } else {
                currentRevision.endElement(uri, localName, qName);
            }
        } else {
            if (localName.equals("title")) {
                title = currentString.toString();
            } else if (localName.equals("id")) {
                id = currentString.toString();
            } else if (localName.equals("restrictions")) {
                restrictions = currentString.toString();
            } else if (localName.equals("redirect")) {
                // nothing to do
            }
        }
    }
    
    /**
     * Translates the {@link XmlPage} object to a {@link Page} object.
     * Throws in case of a malformed XML file.
     * 
     * @return the page
     */
    public Page getPage() {
        return final_page;
    }

    /**
     * Gets all revisions of this page.
     * 
     * @return the revisions
     */
    public List<Revision> getRevisions() {
        return new LinkedList<Revision>(revisions.values());
    }
}
