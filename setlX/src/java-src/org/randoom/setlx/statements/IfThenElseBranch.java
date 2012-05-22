package org.randoom.setlx.statements;

import org.randoom.setlx.exceptions.SetlException;
import org.randoom.setlx.exceptions.TermConversionException;
import org.randoom.setlx.types.Term;
import org.randoom.setlx.utilities.TermConverter;

/*
grammar rule:
statement
    : [...]
    | 'if' '(' condition ')' '{' block '}' ('else' 'if' '(' condition ')' '{' block '}')* ('else' '{' block '}')?
    ;

implemented here as:
                                                                                                      =====
                                                                                                   mStatements
*/

public class IfThenElseBranch extends IfThenAbstractBranch {
    // functional character used in terms
    /*package*/ final static String FUNCTIONAL_CHARACTER = "^ifThenElseBranch";

    private Block   mStatements;

    public IfThenElseBranch(Block statements){
        mStatements = statements;
    }

    public boolean evalConditionToBool() {
        return true;
    }

    public void execute() throws SetlException {
        mStatements.execute();
    }

    protected void exec() throws SetlException {
        execute();
    }

    /* string operations */

    public String toString(int tabs) {
        String result = " else ";
        result += mStatements.toString(tabs, true);
        return result;
    }

    /* term operations */

    public Term toTerm() {
        Term result = new Term(FUNCTIONAL_CHARACTER);
        result.addMember(mStatements.toTerm());
        return result;
    }

    public static IfThenElseBranch termToBranch(Term term) throws TermConversionException {
        if (term.size() != 1) {
            throw new TermConversionException("malformed " + FUNCTIONAL_CHARACTER);
        } else {
            Block block = TermConverter.valueToBlock(term.firstMember());
            return new IfThenElseBranch(block);
        }
    }
}

