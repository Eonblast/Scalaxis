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
package de.zib.scalaris.examples.wikipedia.bliki;

import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * Wiki model which should be used during parsing of xml dumps.
 * 
 * @author Nico Kruber, kruber@zib.de
 */
public class MyParsingWikiModel extends MyWikiModel {

    protected Set<String> includes = new HashSet<String>();

    /**
     * Creates a new wiki model to render wiki text.
     * 
     * @param imageBaseURL
     *            base url pointing to images - can contain ${image} for
     *            replacement
     * @param linkBaseURL
     *            base url pointing to links - can contain ${title} for
     *            replacement
     * @param namespace
     *            namespace of the wiki
     */
    public MyParsingWikiModel(String imageBaseURL, String linkBaseURL,
            MyNamespace namespace) {
        super(imageBaseURL, linkBaseURL, namespace);
    }

    /**
     * Creates a stub template content that has as many parameters as given by
     * the template call. This allows parsing of template contents hidden in
     * parameters.
     * 
     * @param name
     *            the template's name without the namespace
     * @param parameter
     *            the parameters of the template
     * 
     * @return the template's contents
     */
    @Override
    protected String retrievePage(String namespace, String articleName,
            Map<String, String> templateParameters) {
        if (isTemplateNamespace(namespace)) {
            int index = articleName.indexOf(':');
            if (index > 0) {
                String magicWord = articleName.substring(0, index);
                String parameter = articleName.substring(index + 1).trim();
                if (magicWord.equals(MyScalarisMagicWord.MAGIC_PAGES_IN_CATEGORY)
                        || magicWord.equals(MyScalarisMagicWord.MAGIC_PAGES_IN_CAT)) {
//                  {{PAGESINCATEGORY:categoryname}}
//                  {{PAGESINCAT:categoryname}}
                    // -> add as an include
                    addInclude(createFullPageName(getCategoryNamespace(), parameter));
                    return "";
                }
            }
            if (templateParameters != null) {
                StringBuilder result = new StringBuilder(8 * templateParameters.size());
                for (int i = 1; i <= templateParameters.size(); ++i) {
                    result.append("{{{");
                    result.append(i);
                    result.append("}}}\n");
                }
                return result.toString();
            }
            return null;
        }
        // e.g. page inclusions of the form "{{:Main Page/Introduction}}"
        addInclude(createFullPageName(namespace, articleName));
        return null;
    }

    /**
     * Adds an inclusion to the currently parsed page.
     * 
     * @param includedName
     *            the name of the article being included
     */
    public void addInclude(String includedName) {
        includes.add(includedName.intern());
    }

    /* (non-Javadoc)
     * @see de.zib.scalaris.examples.wikipedia.bliki.MyWikiModel#setUp()
     */
    @Override
    public void setUp() {
        super.setUp();
        includes = new HashSet<String>();
    }

    /**
     * @return the references
     */
    public Set<String> getIncludes() {
        return includes;
    }

    /* (non-Javadoc)
     * @see de.zib.scalaris.examples.wikipedia.bliki.MyWikiModel#appendRedirectLink(java.lang.String)
     */
    @Override
    public boolean appendRedirectLink(String redirectLink) {
        // count redirect as include, too:
        addInclude(redirectLink);
        return super.appendRedirectLink(redirectLink.intern());
    }

    /* (non-Javadoc)
     * @see de.zib.scalaris.examples.wikipedia.bliki.MyWikiModel#addLink(java.lang.String)
     */
    @Override
    public void addLink(String topicName) {
        super.addLink(topicName.intern());
    }
}
