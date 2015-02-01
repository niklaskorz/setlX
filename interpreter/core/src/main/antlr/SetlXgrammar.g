grammar SetlXgrammar;

@parser::header {
    import org.randoom.setlx.assignments.*;
    import org.randoom.setlx.exceptions.UndefinedOperationException;
    import org.randoom.setlx.operators.*;
    import org.randoom.setlx.operatorUtilities.*;
    import org.randoom.setlx.statements.*;
    import org.randoom.setlx.statementBranches.*;
    import org.randoom.setlx.types.*;
    import org.randoom.setlx.utilities.*;
    import org.randoom.setlx.utilities.ParameterDef.ParameterType;

    import java.util.ArrayList;
    import java.util.List;
}

@parser::members {
    private final static String SEMICOLON_FOLLOWING_CLASS = "statements which use blocks are not terminated with a semicolon (';')";

    // state of the setlX interpreter
    private State setlXstate;

    public void setSetlXState(final State state) {
        setlXstate = state;
    }

    private void customErrorHandling(final String msg) {
        setlXstate.addToParserErrorCount(1);
        notifyErrorListeners(msg);
    }
}

initBlock returns [Block blk]
    @init{
        FragmentList<Statement> stmnts = new FragmentList<Statement>();
    }
    : (
        statement  { if ($statement.stmnt != null) { stmnts.add($statement.stmnt); } }
      )+
      { $blk = new Block(stmnts); }
    ;

initExpr returns [OperatorExpression oe]
    : expr[false]
      { $oe = $expr.ex; }
    ;

block returns [Block blk]
    @init{
        FragmentList<Statement> stmnts = new FragmentList<Statement>();
    }
    : (
        statement  { if ($statement.stmnt != null) { stmnts.add($statement.stmnt); } }
      )*
      { $blk = new Block(stmnts); }
    ;

statement returns [Statement stmnt]
    @init{
        FragmentList<AbstractIfThenBranch>   ifList     = new FragmentList<AbstractIfThenBranch>();
        FragmentList<AbstractSwitchBranch>   caseList   = new FragmentList<AbstractSwitchBranch>();
        FragmentList<AbstractMatchBranch>    matchList  = new FragmentList<AbstractMatchBranch>();
        FragmentList<AbstractTryCatchBranch> tryList    = new FragmentList<AbstractTryCatchBranch>();
        Condition                            condition  = null;
        Block                                block      = null;
        OperatorExpression                   expression = null;
    }
    : 'class' ID '(' procedureParameters[true] ')' '{' b1 = block ('static' '{' b2 = block '}' {block = $b2.blk;})? '}'
                         { $stmnt = new ClassConstructor($ID.text, new SetlClass($procedureParameters.paramList, $b1.blk, block)); }
      (
        ';' { customErrorHandling(SEMICOLON_FOLLOWING_CLASS); }
      )?
    | 'if'          '(' c1 = condition ')' '{' b1 = block '}'        { ifList.add(new IfThenBranch($c1.cnd, $b1.blk));             }
      (
        'else' 'if' '(' c2 = condition ')' '{' b2 = block '}'        { ifList.add(new IfThenElseIfBranch($c2.cnd, $b2.blk));       }
      )*
      (
        'else'                             '{' b3 = block '}'        { ifList.add(new IfThenElseBranch($b3.blk));                  }
      )?
      { $stmnt = new IfThen(ifList); }
    | 'switch' '{'
      (
        'case' c1 = condition ':' b1 = block                         { caseList.add(new SwitchCaseBranch($c1.cnd, $b1.blk));       }
      )*
      (
        'default'                    ':' b2 = block                  { caseList.add(new SwitchDefaultBranch($b2.blk));             }
      )?
      '}' { $stmnt = new Switch(caseList); }
    | match                                                          { $stmnt = $match.m;                                          }
    | scan                                                           { $stmnt = $scan.s;                                           }
//    | 'for' '(' iteratorChain[false] ('|' condition {condition = $condition.cnd;} )? ')' '{' block '}'
//                                                                     { $stmnt = new For($iteratorChain.ic, condition, $block.blk); }
    | 'while' '(' condition ')' '{' block '}'                        { $stmnt = new While($condition.cnd, $block.blk);             }
    | 'do' '{' block '}' 'while' '(' condition ')' ';'               { $stmnt = new DoWhile($condition.cnd, $block.blk);           }
    | 'try'                                '{' b1 = block '}'
      (
         'catchLng'  '(' v1 = assignableVariable ')' '{' b2 = block '}' { tryList.add(new TryCatchLngBranch($v1.v, $b2.blk));         }
       | 'catchUsr'  '(' v1 = assignableVariable ')' '{' b2 = block '}' { tryList.add(new TryCatchUsrBranch($v1.v, $b2.blk));         }
      )*
      (
         'catch'     '(' v2 = assignableVariable ')' '{' b3 = block '}' { tryList.add(new TryCatchBranch   ($v2.v, $b3.blk));         }
      )?
      { $stmnt = new TryCatch($b1.blk, tryList); }
    | 'check' '{' b1 = block '}' ('afterBacktrack' '{' b2 = block { block = $b2.blk; } '}')?
                                                                     { $stmnt = new Check($b1.blk, block);                         }
    | 'backtrack' ';'                                                { $stmnt = Backtrack.BT;                                      }
    | 'break' ';'                                                    { $stmnt = Break.B;                                           }
    | 'continue' ';'                                                 { $stmnt = Continue.C;                                        }
    | 'exit' ';'                                                     { $stmnt = Exit.E;                                            }
    | 'return' (expr[false] { expression = $expr.ex; } )? ';'        { $stmnt = new Return(expression);                            }
    | 'assert' '(' condition ',' expr[false] ')' ';'                 { $stmnt = (setlXstate.areAssertsDisabled())?
                                                                                   null
                                                                               :
                                                                                   new Assert($condition.cnd, $expr.ex);
                                                                               ;                                                   }
    | assignmentOther  ';'                                           { $stmnt = $assignmentOther.assign;                           }
    | assignmentDirect ';'                                           { $stmnt = new ExpressionStatement($assignmentDirect.assign); }
    | expr[false] ';'                                                { $stmnt = new ExpressionStatement($expr.ex);                 }
    ;

match returns [Match m]
    @init{
        FragmentList<AbstractMatchBranch> matchList  = new FragmentList<AbstractMatchBranch>();
        Condition                         condition  = null;
    }
    : 'match' '(' expr[false] ')' '{'
      (
         'case'  exprList[true] ('|' c1 = condition {condition = $c1.cnd;})? ':' b1 = block
             { matchList.add(new MatchCaseBranch($exprList.exprs, condition, $b1.blk)); condition = null; }
       | regexBranch
             { matchList.add($regexBranch.rb);                                                            }
      )+
      (
        'default' ':' b4 = block
             { matchList.add(new MatchDefaultBranch($b4.blk));                                            }
      )?
      '}'    { $m = new Match($expr.ex, matchList);                                                       }
    ;

scan returns [Scan s]
    @init{
        FragmentList<AbstractMatchScanBranch> scanList  = new FragmentList<AbstractMatchScanBranch>();
        AssignableVariable                    posVar    = null;
    }
    : 'scan' '(' expr[false] ')' ('using' assignableVariable {posVar = $assignableVariable.v;})? '{'
      (
        regexBranch         { scanList.add($regexBranch.rb);                    }
      )+
      (
        'default' ':' block { scanList.add(new MatchDefaultBranch($block.blk)); }
      )?
      '}'          { $s = new Scan($expr.ex, posVar, scanList); posVar = null;  }
    ;

regexBranch returns [MatchRegexBranch rb]
    @init{
        OperatorExpression assignTo = null;
        Condition condition = null;
    }
    : 'regex' pattern = expr[false]
      (
        'as' assign = expr[true] { assignTo = $assign.ex;      }
      )?
      (
        '|'  condition           { condition = $condition.cnd; }
      )?
      ':' block
      { $rb = new MatchRegexBranch(setlXstate, $pattern.ex, assignTo, condition, $block.blk);
        assignTo = null; condition = null; }
    ;

//listOfVariables returns [List<Variable> lov]
//    @init {
//        $lov = new ArrayList<Variable>();
//    }
//    : v1 = variable       { $lov.add($v1.v);             }
//      (
//        ',' v2 = variable { $lov.add($v2.v);             }
//      )*
//    ;

assignableVariable returns [AssignableVariable v]
    : ID { $v = new AssignableVariable($ID.text); }
    ;


variable returns [Variable v]
    : ID { $v = new Variable($ID.text); }
    ;

condition returns [Condition cnd]
    : expr[false]  { $cnd = new Condition($expr.ex); }
    ;

exprList [boolean enableIgnore] returns [FragmentList<OperatorExpression> exprs]
    @init {
        $exprs = new FragmentList<OperatorExpression>();
    }
    : e1 = expr[$enableIgnore]       { $exprs.add($e1.ex); }
      (
        ',' e2 = expr[$enableIgnore] { $exprs.add($e2.ex); }
      )*
    ;

assignmentOther returns [Statement assign]
    : assignable[false]
      (
         '+='  e = expr[false] { $assign = new SumAssignment            ($assignable.a, $e.ex); }
       | '-='  e = expr[false] { $assign = new DifferenceAssignment     ($assignable.a, $e.ex); }
       | '*='  e = expr[false] { $assign = new ProductAssignment        ($assignable.a, $e.ex); }
       | '/='  e = expr[false] { $assign = new QuotientAssignment       ($assignable.a, $e.ex); }
       | '\\=' e = expr[false] { $assign = new IntegerDivisionAssignment($assignable.a, $e.ex); }
       | '%='  e = expr[false] { $assign = new ModuloAssignment         ($assignable.a, $e.ex); }
      )
    ;

assignmentDirect returns [OperatorExpression assign]
    @init {
        FragmentList<AOperator> operators = new FragmentList<AOperator>();
    }
    : assignmentDirectContent[operators] { $assign = new OperatorExpression(operators); }
    ;

assignmentDirectContent [FragmentList<AOperator> operators] returns [OperatorExpression assign]
    : assignable[false] ':='
      (
         assignmentDirectContent[operators]
       | exprContent[false, operators]
      )
      { operators.add(new Assignment($assignable.a)); }
    ;

assignable [boolean enableIgnore] returns [AAssignableExpression a]
    : assignableVariable           { $a = $assignableVariable.v;                              }
//      (
//         '.' variable            { $a = new MemberAccess($a, $variable.v);                  }
//       | '['                     { exprs = new ArrayList<Expr>();                           }
//         e1 = expr[false]        { exprs.add($e1.ex);                                       }
//         (
//           ',' e2 = expr[false]  { exprs.add($e2.ex);                                       }
//         )*
//         ']'                     { $a = new CollectionAccess($a, exprs);                    }
//      )*
//    | '[' explicitAssignList ']' { $a = new AssignListConstructor($explicitAssignList.eil); }
//    | {$enableIgnore}? '_'       { $a = VariableIgnore.VI;                                  }
    ;

//explicitAssignList returns [ExplicitList eil]
//    @init {
//        List<Expr> exprs = new ArrayList<Expr>();
//    }
//    : a1 = assignable[true]       { exprs.add($a1.a);               }
//      (
//        ',' a2 = assignable[true] { exprs.add($a2.a);               }
//      )*                          { $eil = new ExplicitList(exprs); }
//    ;

expr [boolean enableIgnore] returns [OperatorExpression ex]
    @init {
        FragmentList<AOperator> operators = new FragmentList<AOperator>();
    }
    : exprContent[$enableIgnore, operators] { $ex = new OperatorExpression(operators); }
    ;

exprContent [boolean enableIgnore, FragmentList<AOperator> operators]
    : lambdaProcedure          { operators.add(new ProcedureConstructor($lambdaProcedure.lp)); }
    | implication[$enableIgnore, $operators]
    //      (
    //         '<==>' i2 = implication[$enableIgnore] { $ex = new BoolEquals  ($ex, $i2.i); }
    //       | '<!=>' i2 = implication[$enableIgnore] { $ex = new BoolNotEqual($ex, $i2.i); }
    //      )?
    ;

lambdaProcedure returns [Procedure lp]
    : lambdaParameters
      (
        '|->' expr[false] { $lp = new LambdaProcedure($lambdaParameters.paramList, $expr.ex); }
      | '|=>' expr[false] { $lp = new LambdaClosure($lambdaParameters.paramList, $expr.ex);   }
      )
    ;

lambdaParameters returns [ParameterList paramList]
    @init {
        $paramList = new ParameterList();
    }
    : variable             { $paramList.add(new ParameterDef($variable.v.getId(), ParameterType.READ_ONLY)); }
    | '['
      (
       v1 = variable       { $paramList.add(new ParameterDef($v1.v.getId(), ParameterType.READ_ONLY));       }
       (
         ',' v2 = variable { $paramList.add(new ParameterDef($v2.v.getId(), ParameterType.READ_ONLY));       }
       )*
      )?
      ']'
    ;

implication [boolean enableIgnore, FragmentList<AOperator> operators]
    : disjunction[$enableIgnore, $operators]
//      (
//        '=>' im = implication[$enableIgnore] { $i = new Implication($i, $im.i); }
//      )?
    ;

disjunction [boolean enableIgnore, FragmentList<AOperator> operators]
    : conjunction[$enableIgnore, $operators]
//      (
//        '||' c2 = conjunction[$enableIgnore] { $d = new Disjunction($d, $c2.c); }
//      )*
    ;

conjunction [boolean enableIgnore, FragmentList<AOperator> operators]
    : comparison[$enableIgnore, $operators]
//      (
//        '&&' c2 = comparison[$enableIgnore]  { $c = new Conjunction($c, $c2.comp); }
//      )*
    ;

comparison [boolean enableIgnore, FragmentList<AOperator> operators]
    : sum[$enableIgnore, $operators]
//      (
//         '=='    s2 = sum[$enableIgnore] { $comp = new Equals        ($comp, $s2.s); }
//       | '!='    s2 = sum[$enableIgnore] { $comp = new NotEqual      ($comp, $s2.s); }
//       | '<'     s2 = sum[$enableIgnore] { $comp = new LessThan      ($comp, $s2.s); }
//       | '<='    s2 = sum[$enableIgnore] { $comp = new LessOrEqual   ($comp, $s2.s); }
//       | '>'     s2 = sum[$enableIgnore] { $comp = new GreaterThan   ($comp, $s2.s); }
//       | '>='    s2 = sum[$enableIgnore] { $comp = new GreaterOrEqual($comp, $s2.s); }
//       | 'in'    s2 = sum[$enableIgnore] { $comp = new In            ($comp, $s2.s); }
//       | 'notin' s2 = sum[$enableIgnore] { $comp = new NotIn         ($comp, $s2.s); }
//      )?
    ;

sum [boolean enableIgnore, FragmentList<AOperator> operators]
    : product[$enableIgnore, $operators]
      (
          '+' product[$enableIgnore, $operators] { operators.add(new Sum());        }
        | '-' product[$enableIgnore, $operators] { operators.add(new Difference()); }
      )*
    ;

product [boolean enableIgnore, FragmentList<AOperator> operators]
    : reduce[$enableIgnore, $operators]
      (
         '*' reduce[$enableIgnore, $operators] { operators.add(new Product());  }
//       | '/'  r2 = reduce[$enableIgnore, $operators] { operators.add(new Quotient()); }
//       | '\\' r2 = reduce[$enableIgnore] { $p = new IntegerDivision ($p, $r2.r); }
//       | '%'  r2 = reduce[$enableIgnore] { $p = new Modulo          ($p, $r2.r); }
//       | '><' r2 = reduce[$enableIgnore] { $p = new CartesianProduct($p, $r2.r); }
      )*
    ;

reduce [boolean enableIgnore, FragmentList<AOperator> operators]
    : p1 = prefixOperation[$enableIgnore, false, $operators]
//      (
//         '+/' p2 = prefixOperation[$enableIgnore, false] { $r = new SumOfMembersBinary    ($r, $p2.po); }
//       | '*/' p2 = prefixOperation[$enableIgnore, false] { $r = new ProductOfMembersBinary($r, $p2.po); }
//      )*
    ;

prefixOperation [boolean enableIgnore, boolean quoted, FragmentList<AOperator> operators]
    : factor[$enableIgnore, $quoted, $operators]
//      (
//        '**' p = prefixOperation[$enableIgnore, $quoted] { $po = new Power($po, $p.po);         }
//      )?
//    | '+/' po2 = prefixOperation[$enableIgnore, $quoted] { $po = new SumOfMembers    ($po2.po); }
//    | '*/' po2 = prefixOperation[$enableIgnore, $quoted] { $po = new ProductOfMembers($po2.po); }
//    | '#'  po2 = prefixOperation[$enableIgnore, $quoted] { $po = new Cardinality     ($po2.po); }
    | '-'  prefixOperation[$enableIgnore, $quoted, $operators] { operators.add(new Minus()); }
//    | '@'  po2 = prefixOperation[$enableIgnore, true]    { $po = new Quote           ($po2.po); }
    ;

factor [boolean enableIgnore, boolean quoted, FragmentList<AOperator> operators]
    : //'!' f2 = factor[$enableIgnore, $quoted] { $f = new Not($f2.f);              }
//    | TERM '(' termArguments ')' 
//      { $f = new TermConstructor($TERM.text, $termArguments.args); }
//    | 'forall' '(' iteratorChain[$enableIgnore] '|' condition ')'
//      { $f = new Forall($iteratorChain.ic, $condition.cnd); }
//    | 'exists' '(' iteratorChain[$enableIgnore] '|' condition ')'
//      { $f = new Exists($iteratorChain.ic, $condition.cnd); }
//    |
     (
         '(' exprContent[$enableIgnore, $operators] ')'
       | procedure                   { operators.add(new ProcedureConstructor($procedure.pd)); }
       | variable                    { operators.add($variable.v); }
      )
//      (
//         '.' variable                { $f = new MemberAccess($f, $variable.v);       }
//       | call[$enableIgnore, $f]     { $f = $call.c;                                 }
//      )*
//      (
//        '!'                          { $f = new Factorial($f);                       }
//      )?
    | value[$enableIgnore, $quoted]  { operators.add($value.v); }
//      (
//        '!'                          { $f = new Factorial($f);                       }
//      )?
    ;

//termArguments returns [List<Expr> args]
//    : exprList[true] { $args = $exprList.exprs;       }
//    |  /* epsilon */ { $args = new ArrayList<Expr>(); }
//    ;

procedure returns [Procedure pd]
    : 'procedure'       '(' procedureParameters[true] ')' '{' block '}'
      { $pd = new Procedure($procedureParameters.paramList, $block.blk);       }
    | 'cachedProcedure' '(' procedureParameters[false] ')' '{' block '}'
      { $pd = new CachedProcedure($procedureParameters.paramList, $block.blk); }
    | 'closure'         '(' procedureParameters[true] ')' '{' block '}'
      { $pd = new Closure($procedureParameters.paramList, $block.blk);         }
    ;

procedureParameters [boolean enableRw] returns [ParameterList paramList]
    @init {
        $paramList = new ParameterList();
    }
    : pp1 = procedureParameter[$enableRw]       { $paramList.add($pp1.param); }
      (
        ',' pp2 = procedureParameter[$enableRw] { $paramList.add($pp2.param); }
      )*
      (
        ',' dp1  = procedureDefaultParameter    { $paramList.add($dp1.param); }
      )*
      (
        ',' lp1 = procedureListParameter        { $paramList.add($lp1.param); }
      )?
    | dp2 = procedureDefaultParameter           { $paramList.add($dp2.param); }
      (
        ',' dp3 = procedureDefaultParameter     { $paramList.add($dp3.param); }
      )*
      (
        ',' lp2 = procedureListParameter        { $paramList.add($lp2.param); }
      )?
    | lp3 = procedureListParameter              { $paramList.add($lp3.param); }
    | /* epsilon */
    ;

procedureParameter [boolean enableRw] returns [ParameterDef param]
    : {$enableRw}? 'rw' assignableVariable { $param = new ParameterDef($assignableVariable.v.getId(), ParameterType.READ_WRITE); }
    | variable                             { $param = new ParameterDef($variable.v.getId(), ParameterType.READ_ONLY);  }
    ;

procedureDefaultParameter returns [ParameterDef param]
    : assignableVariable ':=' expr[false] { $param = new ParameterDef($assignableVariable.v.getId(), ParameterType.READ_ONLY, $expr.ex); }
    ;

procedureListParameter returns [ParameterDef param]
    : '*' variable { $param = new ParameterDef($variable.v.getId(), ParameterType.LIST); }
    ;

//call [boolean enableIgnore, Expr lhs] returns [Expr c]
//    @init {
//        $c = lhs;
//    }
//    : '(' callParameters[$enableIgnore]         ')' { $c = new Call($c, $callParameters.params, $callParameters.ex); }
//    | '[' collectionAccessParams[$enableIgnore] ']' { $c = new CollectionAccess($c, $collectionAccessParams.params); }
//    | '{' expr[$enableIgnore]                   '}' { $c = new CollectMap($c, $expr.ex);                             }
//    ;

//callParameters [boolean enableIgnore] returns [List<Expr> params, Expr ex]
//    @init {
//        $params = new ArrayList<Expr>();
//        $ex     = null;
//    }
//    : exprList[$enableIgnore] { $params = $exprList.exprs; }
//      (
//         ',' '*' expr[false]  { $ex     = $expr.ex;        }
//      )?
//    | '*' expr[false]         { $ex     = $expr.ex;        }
//    | /* epsilon */
//    ;

//collectionAccessParams [boolean enableIgnore] returns [List<Expr> params]
//    @init {
//        $params = new ArrayList<Expr>();
//    }
//    : e1 = expr[$enableIgnore]      { $params.add($e1.ex);                          }
//      (
//         RANGE_SIGN                 { $params.add(CollectionAccessRangeDummy.CARD); }
//         (
//           e2 = expr[$enableIgnore] { $params.add($e2.ex);                          }
//         )?
//       | (
//           ',' e3 = expr[false]     { $params.add($e3.ex);                          }
//         )+
//      )?
//    | RANGE_SIGN                    { $params.add(CollectionAccessRangeDummy.CARD); }
//      expr[$enableIgnore]           { $params.add($expr.ex);                        }
//    ;

value [boolean enableIgnore, boolean quoted] returns [AZeroOperator v]
//    @init {
//        CollectionBuilder cb = null;
//    }
    : //'[' (collectionBuilder[$enableIgnore] { cb = $collectionBuilder.cb; } )? ']'
//                           { $v = new SetListConstructor(CollectionType.LIST, cb);          }
//    | '{' (collectionBuilder[$enableIgnore] { cb = $collectionBuilder.cb; } )? '}'
//                           { $v = new SetListConstructor(CollectionType.SET, cb);           }
    /*|*/ STRING               { $v = new StringConstructor(setlXstate, $quoted, $STRING.text); }
    | LITERAL              { $v = new LiteralConstructor($LITERAL.text);                    }
    | matrix               { $v = new ValueOperator($matrix.m);                             }
    | vector               { $v = new ValueOperator($vector.v);                             }
    | atomicValue          { $v = new ValueOperator($atomicValue.av);                       }
    | {$enableIgnore}? '_' { $v = VariableIgnore.VI;                                        }
    ;

//collectionBuilder [boolean enableIgnore] returns [CollectionBuilder cb]
//    @init {
//        List<Expr> exprs = new ArrayList<Expr>();
//    }
//    : e1 = expr[$enableIgnore]
//      (
//         ',' e2 = expr[$enableIgnore]
//         (
//            RANGE_SIGN e3 = expr[$enableIgnore]
//            { $cb = new Range($e1.ex, $e2.ex, $e3.ex); }

//          | { exprs.add($e1.ex); exprs.add($e2.ex); }
//            (
//              ',' e3 = expr[$enableIgnore] { exprs.add($e3.ex); }
//            )*
//            (
//               '|' e4 = expr[false] { $cb = new ExplicitListWithRest(exprs, $e4.ex); }
//             | /* epsilon */        { $cb = new ExplicitList        (exprs);         }
//            )
//         )

//       | RANGE_SIGN e3 = expr[$enableIgnore]
//         { $cb = new Range($e1.ex, null, $e3.ex); }

//       | { exprs.add($e1.ex); }
//         (
//            '|' e2 = expr[false] { $cb = new ExplicitListWithRest(exprs, $e2.ex); }
//          | /* epsilon */        { $cb = new ExplicitList        (exprs);         }
//         )

//       | ':' iteratorChain[$enableIgnore]
//         (
//            '|' c1 = condition     { $cb = new SetlIteration($e1.ex, $iteratorChain.ic, $c1.cnd); }
//          | /* epsilon */          { $cb = new SetlIteration($e1.ex, $iteratorChain.ic, null   ); }
//         )

//      )
//    ;

//iteratorChain [boolean enableIgnore] returns [SetlIterator ic]
//    :
//      i1 = iterator[$enableIgnore]   { $ic = $i1.iter;    }
//      (
//        ','
//        i2 = iterator[$enableIgnore] { $ic.add($i2.iter); }
//      )*
//    ;

//iterator [boolean enableIgnore] returns [SetlIterator iter]
//    :
//      assignable[true] 'in' expr[$enableIgnore] { $iter = new SetlIterator($assignable.a, $expr.ex); }
//    ;

matrix returns [SetlMatrix m]
    @init {
        List<SetlVector> vectors = new ArrayList<SetlVector>();
    }
    : '<<'
      (
        vector { vectors.add($vector.v);       }
      )+
      '>>'     { $m = new SetlMatrix(setlXstate, vectors); }
    ;

vector returns [SetlVector v]
    @init {
        ArrayList<Double> doubles  = new ArrayList<Double>();
        String            negative = "";
        double            dbl      = 0.0;
    }
    : '<<'
      (
       (
         '-'             { negative = "-"; }
       | /* epsilon */   { negative = "";  }
       )
       (
         n1 = NUMBER     { dbl = Double.valueOf(negative + $n1.text);     }
       | DOUBLE          { dbl = Double.valueOf(negative + $DOUBLE.text); }
       )
       (
         '/' n2 = NUMBER { dbl /= Double.valueOf(negative + $n2.text); }
       )?
                         { doubles.add(dbl); }
      )+
      '>>'               { $v = new SetlVector(doubles); }
    ;

atomicValue returns [Value av]
    : NUMBER     { $av = Rational.valueOf($NUMBER.text);       }
    | DOUBLE     { try {
                       $av = SetlDouble.valueOf($DOUBLE.text);
                   } catch (UndefinedOperationException uoe) {
                       /*will not happen*/
                   }
                 }
    | 'om'       { $av = Om.OM;                                }
    | 'true'     { $av = SetlBoolean.TRUE;                     }
    | 'false'    { $av = SetlBoolean.FALSE;                    }
    ;

ID              : ('a' .. 'z')('a' .. 'z' | 'A' .. 'Z'| '_' | '0' .. '9')* ;
TERM            : ('^' ID | 'A' .. 'Z' ID?) ;
NUMBER          : '0'|('1' .. '9')('0' .. '9')*;
DOUBLE          : NUMBER? '.' ('0' .. '9')+ (('e' | 'E') ('+' | '-')? ('0' .. '9')+)? ;
RANGE_SIGN      : '..';
STRING          : '"' ('\\'.|~('"'|'\\'))* '"';
LITERAL         : '\'' ('\'\''|~('\''))* '\'';

LINE_COMMENT    : '//' ~('\n' | '\r')*                      { skip(); } ;
MULTI_COMMENT   : '/*' (~('*') | '*'+ ~('*'|'/'))* '*'+ '/' { skip(); } ;
WS              : (' '|'\t'|'\n'|'\r')                      { skip(); } ;

/*
 * This is the desperate attempt at counting mismatched characters as errors
 * instead of the lexers default behavior of emitting an error message,
 * consuming the character and continuing without counting it as an error.
 *
 * Using this rule all unknown characters are added to the token stream
 * and the parser will stumble over them, reporting "mismatched input"
 *
 * Matching any character here works, because the lexer matches rules in order.
 */

REMAINDER       : . ;

