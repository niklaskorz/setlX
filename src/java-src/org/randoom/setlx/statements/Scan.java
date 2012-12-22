package org.randoom.setlx.statements;

import org.randoom.setlx.exceptions.IncompatibleTypeException;
import org.randoom.setlx.exceptions.SetlException;
import org.randoom.setlx.exceptions.TermConversionException;
import org.randoom.setlx.exceptions.UndefinedOperationException;
import org.randoom.setlx.expressions.Expr;
import org.randoom.setlx.expressions.Variable;
import org.randoom.setlx.types.Rational;
import org.randoom.setlx.types.SetlList;
import org.randoom.setlx.types.SetlSet;
import org.randoom.setlx.types.SetlString;
import org.randoom.setlx.types.Term;
import org.randoom.setlx.types.Value;
import org.randoom.setlx.utilities.Environment;
import org.randoom.setlx.utilities.MatchResult;
import org.randoom.setlx.utilities.State;
import org.randoom.setlx.utilities.TermConverter;
import org.randoom.setlx.utilities.VariableScope;

import java.util.ArrayList;
import java.util.List;

/*
grammar rule:
statement
    : [...]
    | 'scan' '(' expr ')' ('using' variable)? '{' [...] '}'
    ;

implemented with different classes which inherit from MatchAbstractScanBranch:
                 ====              ========       =====
                 mExpr             mPosVarm    mBranchList
*/

public class Scan extends Statement {
    // functional character used in terms (MUST be class name starting with lower case letter!)
    private final static String FUNCTIONAL_CHARACTER = "^scan";

    private final Expr                          mExpr;
    private final Variable                      mPosVar;
    private final List<MatchAbstractScanBranch> mBranchList;

    public Scan(final Expr expr, final Variable posVar, final List<MatchAbstractScanBranch> branchList) {
        mExpr       = expr;
        mPosVar     = posVar;
        mBranchList = branchList;
    }

    protected Value exec(final State state) throws SetlException {
        final Value value = mExpr.eval(state);
        if ( ! (value instanceof SetlString)) {
            throw new IncompatibleTypeException(
                "The value '" + value + "' is not a string and cannot be scaned."
            );
        }
        final VariableScope outerScope = state.getScope();
        try {
            SetlString string = (SetlString) value.clone();
            int        charNr   = 1;
            int        lineNr   = 1;
            int        columnNr = 1;
            while(string.size() > 0) {
                int                     largestMatchSize   = Integer.MIN_VALUE;
                MatchAbstractScanBranch largestMatchBranch = null;
                MatchResult             largestMatchResult = null;

                // map of current position in input-string
                final SetlSet  position = new SetlSet();

                final SetlList charEntry = new SetlList(2);
                charEntry.addMember(new SetlString("char"));
                charEntry.addMember(Rational.valueOf(charNr));
                position.addMember(charEntry);

                final SetlList line   = new SetlList(2);
                line.addMember(new SetlString("line"));
                line.addMember(Rational.valueOf(lineNr));
                position.addMember(line);

                final SetlList column   = new SetlList(2);
                column.addMember(new SetlString("column"));
                column.addMember(Rational.valueOf(columnNr));
                position.addMember(column);

                // find branch which matches largest string
                for (final MatchAbstractScanBranch br : mBranchList) {
                    final MatchResult result = br.scannes(state, string);
                    if (result.isMatch()) {
                        final int offset = br.getEndOffset();
                        if (offset > largestMatchSize) {
                            // scope for condition
                            final VariableScope innerScope = outerScope.clone();
                            state.setScope(innerScope);

                            // put current position into scope
                            if (mPosVar != null) {
                                mPosVar.assignUncloned(state, position);
                            }

                            // put all matching variables into scope
                            result.setAllBindings(state);

                            // check conditon
                            if (br.evalConditionToBool(state)) {
                                largestMatchSize   = offset;
                                largestMatchBranch = br;
                                largestMatchResult = result;
                            }

                            // reset scope
                            state.setScope(outerScope);
                        }
                    }
                }
                // execute branch which matches largest string
                if (largestMatchBranch != null && largestMatchResult != null) {
                    // scope for execution
                    final VariableScope innerScope = outerScope.createInteratorBlock();
                    state.setScope(innerScope);

                    // force match variables to be local to this block
                    innerScope.setWriteThrough(false);
                    // put current position into scope
                    if (mPosVar != null) {
                        mPosVar.assignUncloned(state, position);
                    }
                    // put all matching variables into current scope
                    largestMatchResult.setAllBindings(state);
                    // reset WriteThrough, because changes during execution are not strictly local
                    innerScope.setWriteThrough(true);

                    // execute statements
                    final Value execResult = largestMatchBranch.execute(state);

                    // reset scope
                    state.setScope(outerScope);

                    // return if we got a valid return value, or if default branch was largest match
                    if (execResult != null || largestMatchSize == MatchDefaultBranch.END_OFFSET) {
                        return execResult;
                    }

                    // compute positions
                    charNr   += largestMatchSize;
                    columnNr += largestMatchSize;
                    // find lineEndings
                    String matched = string.getMembers(1, largestMatchSize).getUnquotedString();
                    int pos  = 0;
                    int tmp  = 0;
                    int size = 0;
                    while (true) {
                        tmp  = matched.indexOf("\r\n", pos);
                        size = 2;
                        if (tmp < 0) {
                            tmp  = matched.indexOf("\n", pos);
                            size = 1;
                        }
                        if (tmp >= 0) {
                            ++lineNr;
                            pos = tmp + size;
                        } else {
                            break;
                        }
                    }
                    if (pos > 0) {
                        // reduce columnNr by last read lineEnding position
                        columnNr = largestMatchSize - (pos - size);
                    }

                    // reduce scanned string
                    string  = string.getMembers(largestMatchSize + 1, string.size());
                } else {
                    // nothing matched!
                    throw new UndefinedOperationException("Infinite loop in scan-statement detected.");
                }
            }
            return null;
        } finally { // make sure scope is always reset
            state.setScope(outerScope);
        }
    }

    /* Gather all bound and unbound variables in this statement and its siblings
          - bound   means "assigned" in this expression
          - unbound means "not present in bound set when used"
          - used    means "present in bound set when used"
       Optimize sub-expressions during this process by calling optimizeAndCollectVariables()
       when adding variables from them.
    */
    public void collectVariablesAndOptimize (
        final List<Variable> boundVariables,
        final List<Variable> unboundVariables,
        final List<Variable> usedVariables
    ) {
        mExpr.collectVariablesAndOptimize(boundVariables, unboundVariables, usedVariables);

        /* The Variable in this statement get assigned temporarily.
           Collect it into a temporary list and remove it again before returning. */
        final List<Variable> tempAssigned = new ArrayList<Variable>();
        if (mPosVar != null) {
            mPosVar.collectVariablesAndOptimize(new ArrayList<Variable>(), tempAssigned, tempAssigned);
        }
        final int preBound = boundVariables.size();
        boundVariables.addAll(tempAssigned);

        // binding inside an scan are only valid if present in all branches
        // and last branch is an default-branch
        List<Variable> boundHere = null;
        for (final MatchAbstractBranch br : mBranchList) {
            final List<Variable> boundTmp = new ArrayList<Variable>(boundVariables);

            br.collectVariablesAndOptimize(boundTmp, unboundVariables, usedVariables);

            if (boundHere == null) {
                boundHere = new ArrayList<Variable>(boundTmp.subList(preBound, boundTmp.size()));
            } else {
                boundHere.retainAll(boundTmp.subList(preBound, boundTmp.size()));
            }
        }
        while (boundVariables.size() > preBound) {
            boundVariables.remove(boundVariables.size() - 1);
        }
        if (mBranchList.get(mBranchList.size() - 1) instanceof MatchDefaultBranch) {
            boundHere.removeAll(tempAssigned);
            boundVariables.addAll(boundHere);
        }
    }

    /* string operations */

    public void appendString(final StringBuilder sb, final int tabs) {
        Environment.getLineStart(sb, tabs);
        sb.append("scan (");
        mExpr.appendString(sb, 0);
        sb.append(") ");
        if (mPosVar != null) {
            sb.append("using ");
            mPosVar.appendString(sb, 0);
        }
        sb.append("{");
        sb.append(Environment.getEndl());
        for (final MatchAbstractBranch br : mBranchList) {
            br.appendString(sb, tabs + 1);
        }
        Environment.getLineStart(sb, tabs);
        sb.append("}");
    }

    /* term operations */

    public Term toTerm(final State state) {
        final Term result = new Term(FUNCTIONAL_CHARACTER, 3);

        if (mPosVar != null) {
            result.addMember(mPosVar.toTerm(state));
        } else {
            result.addMember(new SetlString("nil"));
        }

        result.addMember(mExpr.toTerm(state));

        final SetlList branchList = new SetlList(mBranchList.size());
        for (final MatchAbstractBranch br: mBranchList) {
            branchList.addMember(br.toTerm(state));
        }
        result.addMember(branchList);

        return result;
    }

    public static Scan termToStatement(final Term term) throws TermConversionException {
        if (term.size() != 3 || ! (term.firstMember() instanceof Term || ! (term.lastMember() instanceof SetlList))) {
            throw new TermConversionException("malformed " + FUNCTIONAL_CHARACTER);
        } else {
            try {
                Variable posVar = null;
                if (! term.firstMember().equals(new SetlString("nil"))) {
                    posVar = Variable.termToExpr((Term) term.firstMember());
                }

                final Expr                          expr        = TermConverter.valueToExpr(term.getMember(2));

                final SetlList                      branches    = (SetlList) term.lastMember();
                final List<MatchAbstractScanBranch> branchList  = new ArrayList<MatchAbstractScanBranch>(branches.size());
                for (final Value v : branches) {
                    branchList.add(MatchAbstractScanBranch.valueToMatchAbstractScanBranch(v));
                }

                return new Scan(expr, posVar, branchList);
            } catch (final SetlException se) {
                throw new TermConversionException("malformed " + FUNCTIONAL_CHARACTER);
            }
        }
    }
}
