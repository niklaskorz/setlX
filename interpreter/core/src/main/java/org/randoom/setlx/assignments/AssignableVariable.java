package org.randoom.setlx.assignments;

import org.randoom.setlx.exceptions.SetlException;
import org.randoom.setlx.types.SetlString;
import org.randoom.setlx.types.Term;
import org.randoom.setlx.types.Value;
import org.randoom.setlx.utilities.CodeFragment;
import org.randoom.setlx.utilities.State;
import org.randoom.setlx.utilities.VariableScope;

import java.util.List;

/**
 * Simple assignment to a variable.
 */
public class AssignableVariable extends AAssignableExpression {
    private final static String FUNCTIONAL_CHARACTER = generateFunctionalCharacter(AssignableVariable.class);

    private final String id;

    /**
     * Create a new Variable expression.
     *
     * @param id ID/name of this variable.
     */
    public AssignableVariable(final String id) {
        this.id = id;
    }

    /**
     * @return ID/name of this variable.
     */
    public String getId() {
        return id;
    }

    @Override
    public boolean collectVariablesAndOptimize(State state, List<String> boundVariables, List<String> unboundVariables, List<String> usedVariables) {
        if (boundVariables.contains(id)) {
            usedVariables.add(id);
        } else {
            unboundVariables.add(id);
        }
        return false;
    }

    @Override
    public void collectVariablesWhenAssigned(State state, List<String> boundVariables, List<String> unboundVariables, List<String> usedVariables) {
        boundVariables.add(id);
    }

    @Override
    public Value evaluate(State state) throws SetlException {
        return state.findValue(id);
    }

    @Override
    public void assignUncloned(State state, Value value, String context) throws SetlException {
        state.putValue(id, value, context);
    }

    @Override
    public boolean assignUnclonedCheckUpTo(State state, Value value, VariableScope outerScope, boolean checkObjects, String context) throws SetlException {
        return state.putValueCheckUpTo(id, value, outerScope, checkObjects, context);
    }

    @Override
    public void appendString(State state, StringBuilder sb, int tabs) {
        sb.append(id);
    }

    @Override
    public Value toTerm(State state) throws SetlException {
        final Term result = new Term(FUNCTIONAL_CHARACTER, 1);
        result.addMember(state, new SetlString(id));
        return result;
    }

    private final static long COMPARE_TO_ORDER_CONSTANT = generateCompareToOrderConstant(AssignableVariable.class);

    @Override
    public int compareTo(CodeFragment other) {
        if (this == other) {
            return 0;
        } else if (other.getClass() == AssignableVariable.class) {
            final AssignableVariable otr = (AssignableVariable) other;
            return id.compareTo(otr.id);
        } else {
            return (this.compareToOrdering() < other.compareToOrdering())? -1 : 1;
        }
    }

    @Override
    public long compareToOrdering() {
        return COMPARE_TO_ORDER_CONSTANT;
    }

    @Override
    public boolean equals(Object obj) {
        return this == obj || obj.getClass() == AssignableVariable.class && id.equals(((AssignableVariable) obj).id);
    }

    @Override
    public int computeHashCode() {
        return ((int) COMPARE_TO_ORDER_CONSTANT) + id.hashCode();
    }
}
