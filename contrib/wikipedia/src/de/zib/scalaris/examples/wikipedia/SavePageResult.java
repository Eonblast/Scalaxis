package de.zib.scalaris.examples.wikipedia;

import java.math.BigInteger;
import java.util.List;

import de.zib.scalaris.examples.wikipedia.data.Page;
import de.zib.scalaris.examples.wikipedia.data.ShortRevision;

/**
 * Result of an operation saving a page, i.e. adding a new revision.
 * 
 * @author Nico Kruber, kruber@zib.de
 */
public class SavePageResult extends Result {
    /**
     * Old version of the page (may be null).
     */
    public Page oldPage = null;
    /**
     * New version of the page (may be null).
     */
    public Page newPage = null;
    /**
     * New list of (short) revisions (may be null).
     */
    public List<ShortRevision> newShortRevs = null;
    /**
     * New number of page edists (may be null).
     */
    public BigInteger pageEdits = null;
    
    /**
     * Creates a new successful result.
     */
    public SavePageResult() {
        super();
    }
    /**
     * Creates a new custom result.
     * 
     * @param success the success status
     * @param message the message to use
     */
    public SavePageResult(boolean success, String message) {
        super(success, message);
    }
}