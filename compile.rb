class Parser
    def initialize(program)
        @prog = program.split(/\s+/)
    end
    def parseProgram
        tree = ParseTreeNode.new("Program",nil,nil)
        statements = []
        begin
            statements.push(parseStatement)
        end while @prog.length > 0
        tree.child = statements
        tree
    end
    def parseStatement
        if @prog[0] == "" then
            @prog.shift
            return parseStatement
        elsif @prog[0] == "if" then
            @prog.shift
            t = ParseTreeNode.new("Statement",[],nil)
            e = parseExpression
            if @prog[0] != "goto" then
                raise "Syntax error: "+@prog[0..3].join(" ")
            end
            @prog.shift
            t.child.push(ParseTreeNode.new("If",nil,"If"))
            t.child.push(e)
            t.child.push(ParseTreeNode.new("Label",nil,@prog.shift))
            if @prog[0] != ";" then
                raise "Syntax error: "+@prog[0..3].join(" ")
            end
            @prog.shift
            return t  
        elsif @prog[0] == "goto" then
            t = ParseTreeNode.new("Statement",[],nil)
            @prog.shift
            t.child.push(ParseTreeNode.new("Goto",nil,"Goto"))
            t.child.push(ParseTreeNode.new("Label",nil,@prog.shift))
            if @prog[0] != ";" then
                raise "Syntax error: "+@prog[0..3].join(" ")
            end
            @prog.shift
            return t
        elsif @prog[0] == "end" then
            @prog.shift
            return ParseTreeNode.new("Statement",[ParseTreeNode.new("End",nil,"End")],nil)   
        elsif @prog[0] == "return" then
            t = ParseTreeNode.new("Statement",[],nil)
            @prog.shift
            t.child.push(ParseTreeNode.new("Return",nil,"Return"))
            e = nil
            if @prog[0] != ";" then
                e = parseExpression
            end   
            unless e.nil? then
                t.child.push(e)
            end
            if @prog[0] != ";" then
                raise "Syntax error: "+@prog[0..3].join(" ")
            end
            @prog.shift
            return t
        elsif @prog[0] == "local" then
            t = ParseTreeNode.new("Statement",[],nil)
            @prog.shift
            lt = ParseTreeNode.new("Local",[],nil)
            t.child.push lt            
            while @prog[0] =~ /^[a-zA-Z0-9]+$/
                lt.child.push ParseTreeNode.new("Variable",nil,@prog[0].upcase)
                @prog.shift
            end
            if @prog[0] != ";" then
                raise "Syntax error: "+@prog[0..3].join(" ")
            end
            @prog.shift
            return t
        elsif @prog[0] =~ /^[a-zA-Z0-9]+$/ and
           @prog[1] == "=" then
           var = @prog.shift.upcase
           @prog.shift
           t = ParseTreeNode.new("Statement",[],nil)
           e = parseExpression
           if @prog[0] != ";" then
               raise "Syntax error: "+@prog[0..3].join(" ")
           end
           @prog.shift
           t.child.push(ParseTreeNode.new("Variable",nil,var))
           t.child.push(ParseTreeNode.new("=",nil,"="))
           t.child.push(e)
           return t
        elsif @prog[0] =~ /^[a-zA-Z_][a-zA-Z0-9_]*:/ then
            lab = @prog.shift.sub(/:/,"").upcase
            t = ParseTreeNode.new("Statement",[],nil)
            if @prog[0] == "func" then
                @prog.shift
                t.child.push(ParseTreeNode.new("FuncName",nil,lab))
                while @prog[0] =~ /^[a-zA-Z0-9]+$/
                    t.child.push(ParseTreeNode.new("Variable",nil,@prog.shift.upcase))
                end
                if @prog[0] != ":" then
                    raise "Syntax error: "+@prog[0..3].join(" ")
                end
                @prog.shift
                return t
            end  
            t.child.push(ParseTreeNode.new("Label",nil,lab))
            return t
        end
        raise "Syntax error: token=#{@prog[0]} context="+@prog[0..3].join(" ")
    end
    def parseExpression
        stack = []
        begin
            case @prog[0]
            when "goto"
                return stack.pop
            when "("
                @prog.shift
                stack.push(parseExpression)
            when "Not"
                @prog.shift
                e = parseExpression
                t = ParseTreeNode.new("Expression",[ParseTreeNode.new("Not",nil,"Not"),e],nil)
                stack.push(t)
            when /^[0-9]+$/
                v = ParseTreeNode.new("Constant",nil,@prog.shift)
                stack.push(ParseTreeNode.new("Expression",[v],nil))
            when /^[a-zA-Z]+$/
                v = ParseTreeNode.new("Variable",nil,@prog.shift.upcase)
                stack.push(ParseTreeNode.new("Expression",[v],nil))
            when /^&[a-zA-Z]+$/
                fname = ParseTreeNode.new("FuncName",nil,@prog.shift[1..-1].upcase)
                e = parseExpression
                v = ParseTreeNode.new("Function",[fname,e],nil)
                stack.push(ParseTreeNode.new("Expression",[v],nil))
            when "+","-","*","/","%","==","<"
                op = @prog.shift
                e2 = parseExpression
                e1 = stack.pop
                t = ParseTreeNode.new("Expression",[e1,ParseTreeNode.new(op,nil,op),e2],nil) 
                stack.push(t)
            when ")"
                @prog.shift
                return stack.pop
            else
                return stack.pop
            end
        end while @prog.length > 0
    end
end 
            
class ParseTreeNode
    attr :type
    attr :child
    attr :content
    def initialize(type,children,content)
        @type = type
        @child = children
        @content = content
    end
    def child=(val)
        @child = val
    end
    def ParseTreeNode.from_a(ary)
        # ary = [NodeName, child/content]
        name = ary[0]
        cont = ary[1]
        if name =~ /^[A-Z]/ then # Nonterminal
            child = []
            content = nil
            if cont.kind_of?(Array) then
                for c in cont
                    child.push ParseTreeNode.from_a(c)
                end
            else
                content = cont
            end
            ParseTreeNode.new(name,child,content)
        else #terminal
            ParseTreeNode.new(name,nil,cont)
        end
    end
    def nonterminal?
        not @child.nil?
    end
    def terminal?
        @child.nil?
    end
    def to_s
        if @type == @content then
            @type
        elsif terminal? then
            "("+@type+" "+@content+")"
        else
            "("+@type+" "+@child.collect{|x| x.to_s }.join(" ")+")"
        end
    end
    def pretty(level=0,out=$stdout)
        if terminal? then
            out.print " "*(level*4)+"("+@type+" "+@content+")\n"
        else
            out.print " "*(level*4)+"("+@type+"\n"
            for ch in @child
                ch.pretty(level+1)
            end
            out.print " "*(level*4)+")\n"
        end
    end
        
end

class Quadruple
    attr :q
    def initialize(op,x1,x2,dest)
        @q = [op,x1,x2,dest]
    end
    def to_s
        "("+@q.join(",")+")"
    end
end

class LocalVariableList
    attr :var
    attr :varnum
    def initialize
        @var = {"_retval" => 0}
        @varnum = 1
        @frame = 0
    end
    def var(name)
        if @var[name] then
            @frame-@var[name]
        else
            nil
        end
    end
    def register(name)
        @var[name] = @varnum
        @varnum += 1
    end
    def addframe(n)
        @frame += n
    end
    def frame
        @frame
    end
end        

class QuadrupleGenerator
    @@seq = 0
    def initialize(stream)
        @stream = stream
        @localvars = LocalVariableList.new
    end
    def tmpname
        @@seq += 1
        "T"+@@seq.to_s
    end
    def generate(n)
        case n.type
        when "Program"
            for m in n.child
                generate(m)
            end
        when "Statement"
            if n.child.size > 2 and n.child[1].content == "=" then
                # child is "var = exp ;"
                var = n.child[0].content
                lvar = @localvars.var(var)
                var = "@#{lvar}" unless lvar.nil?
                exp = n.child[2]
                t = tmpname
                expression(exp,t)
                @stream.push Quadruple.new("=", t, nil, var)
            elsif n.child[0].content == "If" then
                t = tmpname
                expression(n.child[1],t)
                lab = n.child[2].content
                @stream.push Quadruple.new("cjump",t,nil,lab)
            elsif n.child[0].content == "Goto" then
                lab = n.child[1].content.upcase
                @stream.push Quadruple.new("jump",t,nil,lab)
            elsif n.child[0].type == "Label" then
                @stream.push Quadruple.new("label",nil,nil,n.child[0].content.upcase)
            elsif n.child[0].type == "End" then
                @stream.push Quadruple.new("end",nil,nil,n.child[0].content.upcase)
            elsif n.child[0].type == "FuncName" then
                @stream.push Quadruple.new("function",nil,nil,n.child[0].content.upcase)
                @localvars = LocalVariableList.new
                @localvars.register(n.child[1].content)
                @localvars.addframe(1)
                #@stream.push Quadruple.new("frame",nil,nil,1)
            elsif n.child[0].type == "Return" then
                t = tmpname
                expression(n.child[1],t)
                @stream.push Quadruple.new("=",t,nil,"@"+@localvars.var("_retval").to_s)
                nframe = @localvars.frame-1
                if nframe > 0 then
                    @stream.push Quadruple.new("frame","-#{nframe}",nil,nil)
                end
                @stream.push Quadruple.new("return",nil,nil,nil)
            elsif n.child[0].type == "Local" then
                k = 0
                for vn in n.child[0].child
                    @localvars.register(vn.content.upcase)
                    k += 1
                end
                @localvars.addframe(k)
                @stream.push Quadruple.new("frame",k.to_s,nil,nil)
            end
        else
            raise "Quadruple generation error: unknown node Statement::"+n.child[0].content
        end
    end
    def expression(e,tmpvar)
        operators = {
            "+" => true,
            "-" => true,
            "*" => true,
            "/" => true,
            "%" => true,
            "==" => true,
            "<" => true
        }
        if e.child[0].type == "Constant" then
            @stream.push Quadruple.new("=", e.child[0].content,nil,tmpvar)
        elsif e.child[0].type == "Variable" then
            varname = e.child[0].content
            lvar = @localvars.var(varname)
            if lvar.nil? then
                @stream.push Quadruple.new("=", varname, nil, tmpvar)
            else
                @stream.push Quadruple.new("=", "@#{lvar}",nil,tmpvar)
            end
        elsif e.child[0].type == "Function" then
            fn = e.child[0]
            t = tmpname
            expression(fn.child[1],t)
            @stream.push Quadruple.new("arg",t,nil,nil)
            @stream.push Quadruple.new("call",fn.child[0].content,nil,tmpvar)
        elsif e.child[0].type == "(" and e.child[2].type == ")" then
            expression(e.child[1],tmpvar)
        elsif e.child[0].type == "Not" then
            t1 = tmpname
            expression(e.child[1],t1)
            @stream.push Quadruple.new("not",t1,nil,tmpvar)
        elsif operators[e.child[1].type] then
            t1 = tmpname
            t2 = tmpname
            expression(e.child[0],t1)
            expression(e.child[2],t2)
            @stream.push Quadruple.new(e.child[1].type,t1, t2, tmpvar)
        end
    end
end

class Optimizer
    def initialize(q)
        @q = q
        @tvars = {}
        for x in q
            for i in 1..3
                @tvars[x.q[i]] = true if x.q[i] =~ /T\d+/
            end
        end   
    end
    def optimize
        begin
            modified = false
            modified |= optimize1
            modified |= optimize2
        end while modified
        @q
    end
    def optimize1
        modified = false
        for v in @tvars.keys
            v1 = v2 = nil
            stop = false
            nq = []
            @q.each_index do |i|
                if @q[i].q[3] == v then
                    v1 = i
                elsif @q[i].q[0] == "=" and @q[i].q[1] == v then
                    if v2.nil? then
                        v2 = i
                    else
                        stop =   true
                    end
                elsif @q[i].q[1] == v or @q[i].q[2] == v then
                    stop = true
                end
            end
            if not stop and not v1.nil? and not v2.nil? then
                @q.each_index do |i|
                    if i == v1 then
                        nq.push(Quadruple.new(@q[i].q[0],@q[i].q[1],@q[i].q[2],@q[v2].q[3]))
                    elsif i == v2 then
                        next
                    else
                        nq.push(@q[i])
                    end
                end
                @q = nq
                modified = true
            end
        end
        modified
    end
    def optimize2
        modified = false
        for v in @tvars.keys
            v1 = v2 = nil
            stop = false
            nq = []
            @q.each_index do |i|
                if @q[i].q[1] == v or @q[i].q[2] == v then
                    v2 = i
                elsif @q[i].q[0] == "=" and @q[i].q[3] == v then
                    v1 = i
                end
            end
            if not v1.nil? and not v2.nil? then
                var = nil
                @q.each_index do |i|
                    if i == v1 then
                        var = @q[i].q[1]
                    elsif i == v2 then
                        o1 = @q[i].q[1]
                        o2 = @q[i].q[2]
                        o1 = var if o1 == v
                        o2 = var if o2 == v
                        nq.push(Quadruple.new(@q[i].q[0],o1,o2,@q[i].q[3]))
                    else
                        nq.push(@q[i])
                    end
                end
                @q = nq
                modified = true
            end
        end
        modified
    end
end     

class CodeGenerator
    def initialize(q)
        @q = q
        @vars = {}
        @labelnum = 0
    end
    def newlabel
        lab = "L"+@labelnum.to_s
        @labelnum += 1
        lab
    end
    def register_load(reg,arg)
        if arg[0] == "=" then
            "LAD "+reg+","+arg[1..-1]
        elsif arg =~ /^@/ then
            fr = arg[1..-1]
            "LD #{reg},#{fr},GR7"
        else
            "LD #{reg},#{arg}"
        end
    end
    def generate
        out = []
        labelop = {
            "label" => true,
            "jump" => true,
            "cjump" => true,
            "function" => true,
            "start" => true,
            "end" => true,
        }
        current_module = ""
        for q in @q
            op,e1,e2,dest = q.q
            if e1 =~ /^\-*\d+$/ then
              e1 = "="+e1
            elsif e1 =~ /[a-zA-Z]/ and op != "call" then
              @vars[e1] = true
            end 
            if e2 =~ /^\-*\d+$/ then
              e2 = "="+e2
            elsif e2 =~ /[a-zA-Z]/ then
              @vars[e2] = true
            end 
            if dest =~ /[a-zA-Z]/ and !labelop[op] then
              @vars[dest] = true
            elsif dest =~ /^@/ then
                dest = dest[1..-1]+",GR7"
            end
            case op
            when "="
                out.push(["",register_load("GR0",e1)])
                out.push(["","ST GR0,#{dest}"])
            when "+"
                out.push(["",register_load("GR0",e1)])
                out.push(["","ADDA GR0,#{e2}"])
                out.push(["","ST GR0,#{dest}"])
            when "-"
                out.push(["",register_load("GR0",e1)])
                out.push(["","SUBA GR0,#{e2}"])
                out.push(["","ST GR0,#{dest}"])
            when "=="
                lab = newlabel
                out.push(["","LAD GR1,1"])
                out.push(["",register_load("GR0",e1)])
                out.push(["","CPA GR0,#{e2}"])
                out.push(["","JZE #{lab}"])
                out.push(["","LAD GR1,0"])
                out.push([lab,"ST GR1,#{dest}"])
            when "<"
                lab = newlabel
                out.push(["","LAD GR1,1"])
                out.push(["",register_load("GR0",e1)])
                out.push(["","CPA GR0,#{e2}"])
                out.push(["","JMI #{lab}"])
                out.push(["","LAD GR1,0"])
                out.push([lab,"ST GR1,#{dest}"])
            when "*"
                out.push(["",register_load("GR1",e1)])
                out.push(["",register_load("GR2",e2)])
                out.push(["","CALL FMULT"])
                out.push(["","ST GR0,#{dest}"])
            when "/"
                out.push(["",register_load("GR1",e1)])
                out.push(["",register_load("GR2",e2)])
                out.push(["","CALL FDIV"])
                out.push(["","ST GR0,#{dest}"])
            when "%"
                out.push(["",register_load("GR1",e1)])
                out.push(["",register_load("GR2",e2)])
                out.push(["","CALL FDIV"])
                out.push(["","ST GR3,#{dest}"])
            when "not"
                lab = newlabel
                out.push(["",register_load("GR0",e1)])
                out.push(["","JZE #{lab}"])
                out.push(["","LAD GR0,#FFFF"])
                out.push([lab,"ADDA GR0,=1"])
                out.push(["","ST GR0,#{dest}"])
            when "label"
                out.push([dest,"NOP"])
            when "function"
                current_module = dest.upcase
                out.push([current_module,"START"])
            when "jump"
                out.push(["","JUMP #{dest.upcase}"])
            when "cjump"
                out.push(["",register_load("GR0",e1)])
                out.push(["","JNZ #{dest.upcase}"])
            when "start"
                current_module = dest.upcase
                out.push([current_module,"START"])
                if  current_module == "PROG" then
                    out.push(["","LAD GR7,256"])
                    out.push(["","LAD GR7,CSTACK,GR7"])
                end
            when "end"
                finish(out,current_module)
                @vars = {}
            when "arg"
                out.push(["","SUBL GR7,=2"])
                out.push(["","LD GR0,#{e1}"])
                out.push(["","ST GR0,0,GR7"])
            when "call"
                out.push(["","CALL #{e1}"])
                out.push(["","LD GR0,1,GR7"])
                out.push(["","ST GR0,#{dest}"])
                out.push(["","ADDL GR7,=2"])
            when "return"
                out.push(["","RET"])
            when "frame"
                nf = e1[1..-1].to_i
                if nf < 0 then
                    out.push(["","ADDL GR7,=#{-nf}"])
                else
                    out.push(["","SUBL GR7,=#{nf}"])
                end
            else
                raise "Bad operation: #{op}"
            end
        end
        if out[-1][1] != "END" then
            finish(out,current_module)
        end

        out
    end
    def finish(out,current)
        if out[-1][1] != "RET" then
            out.push(["","RET"])
        end
        for v in variables
            out.push([v,"DS 1"])
        end
        if current == "PROG" then
            out.push(["CSTACK","DS 256"])
        end
        out.push(["","END"])
    end
    def variables
        @vars.keys
    end
end        

do_optimize = true

while ARGV[0] =~ /^-/
    case ARGV.shift
    when "-nopt"
        do_optimize = false
    end
end
program = nil
if ARGV.size > 0
    program = IO.readlines(ARGV.shift).join(" ")
else
    program = "a = ( b + c ) - 1 ;"
end

print "***PROGRAM***\n"
print program,"\n"
parser = Parser.new(program)
pt = parser.parseProgram
print "***Parse tree***\n"
#print pt.to_s+"\n"
pt.pretty

qout = [Quadruple.new("start",nil,nil,"PROG")]
gen = QuadrupleGenerator.new(qout)
gen.generate(pt)
print "***Quadruples***\n"
for q in qout
    print q.to_s,"\n"
end
if do_optimize then
    print "***Optimized***\n"
    opt = Optimizer.new(qout)
    qopt = opt.optimize
    for q in qopt
        print q.to_s,"\n"
    end
else
    qopt = qout
end
print "***Code Generation***\n"
cgen = CodeGenerator.new(qopt)
#p cgen.generate
for c in cgen.generate
    print c.join("\t"),"\n"
end
open("library.cas") do |f|
    while l=f.gets
        print l
    end
end

