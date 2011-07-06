package de.zib.scalaris.examples.wikipedia;

import java.util.List;

import de.zib.scalaris.examples.wikipedia.data.Page;
import de.zib.scalaris.examples.wikipedia.data.ShortRevision;

/**
 * Result of an operation getting the page history.
 * 
 * @author Nico Kruber, kruber@zib.de
 */
public class PageHistoryResult extends Result {
    /**
     * The retrieved page on success (or <tt>null</tt>).
     */
    public Page page = null;
    /**
     * The retrieved (short) revisions on success (or <tt>null</tt>).
     */
    public List<ShortRevision> revisions = null;
    /**
     * Whether the page exists or not.
     */
    public boolean not_existing = false;

    /**
     * Creates a successful result with an empty message and the given
     * revisions.
     * 
     * @param page      the retrieved page
     * @param revisions the retrieved (short) revisions
     */
    public PageHistoryResult(Page page, List<ShortRevision> revisions) {
        super();
        this.page = page;
        this.revisions = revisions;
    }
    /**
     * Creates a new custom result.
     * 
     * @param success the success status
     * @param message the message to use
     */
    public PageHistoryResult(boolean success, String message) {
        super(success, message);
    }
}