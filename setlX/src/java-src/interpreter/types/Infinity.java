package interpreter.types;

import interpreter.exceptions.IncompatibleTypeException;
import interpreter.exceptions.SetlException;
import interpreter.exceptions.UndefinedOperationException;

public class Infinity extends NumberValue {

    public final static Infinity POSITIVE = new Infinity();
    public final static Infinity NEGATIVE = new Infinity();

    private Infinity() {  }

    public Infinity clone() {
        // this value is more or less atomic and can not be changed once set
        return this;
    }

    public static Infinity get(boolean positive){
        if (positive) {
            return POSITIVE;
        } else {
            return NEGATIVE;
        }
    }

    /* type checks (sort of Boolean operation) */

    public SetlBoolean isInfinity() {
        return SetlBoolean.TRUE;
    }

    /* arithmetic operations */

    public Infinity absoluteValue() {
        return POSITIVE;
    }

    public Value difference(Value subtrahend) throws SetlException {
        if (subtrahend instanceof NumberValue) {
            if (this == subtrahend) {
                throw new UndefinedOperationException("'" + this + " + " + subtrahend + "' is undefined.");
            }
            return this;
        } else if (subtrahend instanceof Term) {
            return ((Term) subtrahend).differenceFlipped(this);
        } else {
            throw new IncompatibleTypeException("Right-hand-side of '" + this + " - " + subtrahend + "' is not a number.");
        }
    }

    public Value divide(Value divisor) throws SetlException {
        if (divisor == POSITIVE || divisor == NEGATIVE) {
            throw new UndefinedOperationException("'" + this + " / " + divisor + "' is undefined.");
        } else if (divisor instanceof NumberValue) {
            if (divisor.compareTo(new Rational(0)) < 0) {
                return this.negate();
            } else if (divisor.compareTo(new Rational(0)) == 0) {
                throw new UndefinedOperationException("'" + this + " / 0' is undefined.");
            } else {
                return this;
            }
        } else if (divisor instanceof Term) {
            return ((Term) divisor).divideFlipped(this);
        } else {
            throw new IncompatibleTypeException("Right-hand-side of '" + this + " / " + divisor + "' is not a number.");
        }
    }

    public Value multiply(Value multiplier) throws SetlException {
        if (multiplier instanceof NumberValue) {
            if (this == multiplier) {
                return POSITIVE;
            } else if (this == multiplier.negate()) {
                return NEGATIVE;
            } else if (multiplier.compareTo(new Rational(0)) < 0) {
                return this.negate();
            } else if (multiplier.compareTo(new Rational(0)) == 0) {
                throw new UndefinedOperationException("'" + this + " * 0' is undefined.");
            } else {
                return this;
            }
        } else if (multiplier instanceof Term) {
            return ((Term) multiplier).multiplyFlipped(this);
        } else {
            throw new IncompatibleTypeException("Right-hand-side of '" + this + " * " + multiplier + "' is not a number.");
        }
    }

    public Infinity negate() {
        if (this == POSITIVE) {
            return NEGATIVE;
        } else { // this == NEGATIVE
            return POSITIVE;
        }
    }

    public NumberValue power(int exponent) throws UndefinedOperationException{
        throw new UndefinedOperationException("'" + this + " ** " + exponent + "' is undefined.");
    }

    public Value sum(Value summand) throws SetlException {
        if (summand instanceof NumberValue) {
            if (this == summand.negate()) {
                throw new UndefinedOperationException("'" + this + " + " + summand + "' is undefined.");
            }
            return this;
        } else if (summand instanceof Term) {
            return ((Term) summand).sumFlipped(this);
        } else if (summand instanceof SetlString) {
            return ((SetlString)summand).sumFlipped(this);
        } else {
            throw new IncompatibleTypeException("Right-hand-side of '" + this + " + " + summand + "' is not a number or string.");
        }
    }

    /* string and char operations */

    public String toString() {
        if (this == POSITIVE) {
            return "oo";
        } else { // this == NEGATIVE
            return "-oo";
        }
    }

    /* comparisons */

    /* Compare two Values.  Return value is < 0 if this value is less than the
     * value given as argument, > 0 if its greater and == 0 if both values
     * contain the same elements.
     * Useful output is only possible if both values are of the same type.
     * "incomparable" values, e.g. of different types are ranked as follows:
     * SetlError < Om < -Infinity < SetlBoolean < Rational & Real < SetlString < SetlSet < SetlList < Term < ProcedureDefinition < +Infinity
     * This ranking is necessary to allow sets and lists of different types.
     */
    public int compareTo(Value v) {
        if (this == v) {
            return 0;
        } else if (this == POSITIVE) {
            // everything else is smaller
            return 1;
        } else if (v instanceof SetlError || v == Om.OM) { // to get here this must be NEGATIVE
            // SetlError and Om are the only things smaller when this is NEGATIVE
            return 1;
        } else {
            // everything in between is bigger
            return -1;
        }
    }
}
