from strutils import PrintableChars
from strformat import formatValue
import ./lexer, ./env, ./box
import questionable/options

type
  LitKind* = enum
    litInt    = "INT"
    litChr    = "CHR"
    litFloat  = "FLOAT"
    litStr    = "STR"
  Lit* = object
    case kind*: LitKind
    of litInt:
      i*: BiggestInt
    of litChr:
      c*: char
    of litFloat:
      f*: float
    of litStr:
      s*: string
  OpKind* = enum
    opNone
    opPlus      = "+"
    opMinus     = "-"
    opAsterisk  = "*"
    opSlash     = "/"
    opLt        = "<"
    opAssign    = "="
    opGt        = ">"
    opLe        = "<="
    opEq        = "=="
    opGe        = ">="
    opNot       = "not"
    opNeq       = "!="
    opAnd       = "and"
    opOr        = "or"
    opDot       = "."
    opIndex     = "[]"
  Op* = object
    kind*: OpKind
    operands*: seq[Expr]
  Block*[T] = object
    scope*: Scope
    code*: seq[T]
  FcExpr* {.pure, inheritable.} = object
    params*: seq[Field]
    ret*: Box[Expr]
    body*: Block[Stmt]
  FcDecl* = object of FcExpr
    name*: string
  FcType* {.pure.} = object
    params*: seq[Expr]
    ret*: Box[Expr]
  ExprKind* = enum
    exprNone
    exprLit
    exprIdent
    exprOp
    exprFc
    exprFcCall
    exprFcType
    exprBracket
    exprBoxVal
  FcCall* = object
    callee*:Box[Expr]
    args*: seq[Expr]
  Expr* = object
    case kind*: ExprKind
    of exprLit:
      lit*: Lit
    of exprIdent:
      ident*: string
    of exprOP:
      op*: Op
    of exprFc:
      fc*: FcExpr
    of exprFcCall:
      fcCall*: FcCall
    of exprFcType:
      fcType*: FcType
    of exprBracket:
      bracket*: seq[Expr]
    of exprBoxVal:
      boxVal*: seq[(?string, Expr)]
    else: discard
  Field* {.pure, inheritable.} = object
    name*: string
    typ*: Expr
  VarDecl* = object of Field
    value*: Expr
  BoxDecl* = object
    name*: string
    fields*: seq[Field]
  IfClause* = tuple[cond: Expr, body: Block[Stmt]]
  IfStmt* = seq[IfClause]
  WhlLoop* {.pure, inheritable.} = object
    cond*: Expr
    body*: Block[Stmt]
  ForLoop* = object of WhlLoop
    init*: Box[Stmt]
    step*: Expr
  ForInLoop* = object
    capture*: string
    iter*: Expr
    body*: Block[Stmt]
  StmtKind* = enum
    stmtNone
    stmtExpr
    stmtVarDecl
    stmtIf
    stmtForLoop
    stmtForInLoop
    stmtWhlLoop
    stmtFcDecl
    stmtRet
  Stmt* = object
    span*: Span
    case kind*: StmtKind
    of stmtNone: discard
    of stmtExpr:
      expr*: Expr
    of stmtVarDecl:
      varDecl*: VarDecl
    of stmtIf:
      ifs*: IfStmt
    of stmtForLoop:
      forl*: ForLoop
    of stmtForInLoop:
      forinl*: ForInLoop
    of stmtWhlLoop:
      whll*: WhlLoop
    of stmtFcDecl:
      fcDecl*: FcDecl
    of stmtRet:
      ret*: Expr
  TopLevelKind* = enum tlNone, tlFcDecl, tlBoxDecl, tlModVar
  TopLevel* = object
    span*: Span
    case kind: TopLevelKind
    of tlNone: discard
    of tlFcDecl:
      fcDecl*: FcDecl
    of tlBoxDecl:
      boxDecl*: BoxDecl
    of tlModVar:
      globVar*: VarDecl
  Module* = object
    name*: string
    # vars*: seq[tuple[name: string, typ: TypeID]]
    code*: Block[TopLevel]
    env*: Env
  Ast* = ref object
    modules*: seq[Module]
    # typeEnv*: TypeEnv

func `$`*(lit: Lit): string =
  case lit.kind
  of litInt: result = $lit.i
  of litChr:
    result.add('\'')
    if lit.c == '\n':
      result.add("\\n")
    elif lit.c == '\r':
      result.add("\\r")
    elif lit.c in PrintableChars:
      result.add(lit.c)
    else:
      result.add"\x"
      result.formatValue(lit.c.int, "02x")
    result.add('\'')
  of litFloat: result.formatValue(lit.f, ".6")
  of litStr:
    result.add('"')
    for c in lit.s:
      if c == '"':
        result.add"\"
      if c == '\n':
        result.add("\\n")
      elif c == '\r':
        result.add("\\r")
      elif c in PrintableChars:
        result.add(c)
      else:
        result.add"\x"
        result.formatValue(c.int, "02x")
    result.add('"')

proc initBlock*[T](prev = none(ptr Scope)): Block[T] =
  result.code = newSeq[T]()
  result.scope = initScope(prev)

proc newAst*(): Ast =
  new(result)
  result.modules = newSeq[Module]()

func initModule*(name: string): Module =
  result.name = name
  # result.globs = newSeq[(string, TypeID)]()
  result.env = newEnv()
  result.code = initBlock[TopLevel](none(ptr Scope))
