structure tigercodegen :> tigercodegen =
struct

open tigerframe
open tigertree
open tigerassem
open tigertemp
open tigerutils

fun salto EQ  = "je" 
  | salto NE  = "jne"
  | salto LT  = "jl"
  | salto GE  = "jge"
  | salto GT  = "jg"
  | salto LE  = "jle"
(*
  | salto ULT = "jb"
  | salto UGE = "ja"
  | salto ULE = "jbe"
  | salto UGT = "jae"
*)
(*
val codegen: tigerframe.frame -> tigertree.stm -> tigerassem.instr list
*)
fun codegen frame stm = 
	let val ilist = ref ([]:(instr list)) (*lista de instrucciones que va a ir mutando*)
        fun emit x = ilist := x::(!ilist) (*!ilist es equivalente a *ilist en C y ilist := a es equivalente a *ilist = a en C*)
        fun result gen = let val t = tigertemp.newtemp() in (gen t; t) end
        fun munchExp (CONST i) = result (fn r => emit(OPER{assem = "movq $"^(toString i)^", %'d0", src = [], dst = [r], jump = NONE}))
        | munchExp (NAME lab) = result (fn r => emit(OPER{assem = "leaq "^(makeString lab)^"(%rip), %'d0", src = [], dst = [r], jump = NONE})) (*se podria retornar lab directo pero por las dudas*)
        | munchExp (MEM m) = result (fn r => emit(OPER{assem = "movq (%'s0), %'d0", src =[munchExp m] , dst=[r], jump=NONE}))
        | munchExp (TEMP t) = t
        | munchExp (CALL _) = raise Fail "CALL no debería aparecer luego de canonizar 234235"
        | munchExp (ESEQ _) = raise Fail "ESEQ no debería aparecer luego de canonizar 3453453"
        | munchExp (BINOP (PLUS, CONST i, e1)) = result ( fn r => (emit(MOV{assem = "movq %'s0, %'d0", src = munchExp e1, dst=r}); emit(OPER{assem = "addq $"^(toString i)^", %'d0", src = [r], dst = [r], jump = NONE})))
        | munchExp (BINOP (PLUS, e1, CONST i)) = munchExp (BINOP (PLUS, CONST i, e1))
        | munchExp (BINOP (PLUS, e1, e2)) = result ( fn r => (emit(MOV{assem = "movq %'s0, %'d0", src=munchExp e1, dst=r}); emit(OPER{assem = "addq %'s1, %'d0", src = [r, munchExp e2], dst = [r], jump = NONE})))
        | munchExp (BINOP (MINUS, CONST i, e1)) = result ( fn r => (emit(OPER{assem = "movq $"^(toString i)^", %'d0", src = [], dst=[r], jump=NONE}); emit(OPER{assem = "subq %'s1, %'d0", src = [r, munchExp e1], dst = [r], jump = NONE})))
        | munchExp (BINOP (MINUS, e1, CONST i)) = result ( fn r => (emit(MOV{assem = "movq %'s0, %'d0", src = munchExp e1, dst=r}); emit(OPER{assem = "subq $"^(toString i)^", %'d0", src = [r], dst = [r], jump = NONE})))
        | munchExp (BINOP (MINUS, e1, e2)) = result ( fn r => (emit(MOV{assem = "movq %'s0, %'d0", src=munchExp e1, dst=r}); emit(OPER{assem = "subq %'s1, %'d0", src = [r, munchExp e2], dst = [r], jump = NONE})))
        | munchExp (BINOP (MUL, e1, CONST i)) = result ( fn r => (emit(OPER{assem = "imulq $"^(toString i)^", %'s0, %'d0", src=[munchExp e1], dst=[r], jump=NONE})))
        | munchExp (BINOP (MUL, CONST i, e1)) = munchExp (BINOP (MUL, e1, CONST i))
        | munchExp (BINOP (MUL, e1, e2)) = result ( fn r => (emit(MOV{assem = "movq %'s0, %'d0", src=munchExp e1, dst=r}); emit(OPER{assem = "imulq %'s1, %'d0", src = [r, munchExp e2], dst = [r], jump = NONE})))
        | munchExp (BINOP (DIV, CONST i, e1)) = result ( fn r => (
			let val m1 = munchExp e1
				val _ = emit(OPER{assem = "movq $"^(toString i)^", %'d0", src=[], dst=[tigerframe.rax], jump = NONE}) 
				val _ = emit(OPER{assem = "cqto", src=[tigerframe.rax], dst=[tigerframe.rdx, tigerframe.rax], jump = NONE})
				val _ = emit(OPER{assem = "idivq %'s2", src = [tigerframe.rax, tigerframe.rdx, m1], dst = [tigerframe.rax, tigerframe.rdx], jump = NONE})
				val _ = emit(MOV{assem = "movq %'s0, %'d0", src=tigerframe.rax, dst=r} ) 
			in
				()
			end))
        | munchExp (BINOP (DIV, e1, CONST i)) = result ( fn r => (
			let val m1 = munchExp e1
				val _ = emit(OPER{assem = "movq $"^(toString i)^", %'d0", src=[], dst=[r], jump = NONE})
				val _ = emit(MOV{assem = "movq %'s0, %'d0", src=m1, dst=tigerframe.rax} )
				val _ = emit(OPER{assem = "cqto", src=[tigerframe.rax], dst=[tigerframe.rdx, tigerframe.rax], jump = NONE})
				val _ = emit(OPER{assem = "idivq %'s2", src = [tigerframe.rax, tigerframe.rdx, r], dst = [tigerframe.rax, tigerframe.rdx], jump = NONE})
				val _ = emit(MOV{assem = "movq %'s0, %'d0", src=tigerframe.rax, dst=r} )
			in
				()
			end))
		| munchExp (BINOP (DIV, e1, e2)) = result ( fn r => (
			let val m1 = munchExp e1
				val m2 = munchExp e2
				val _ = emit(MOV{assem = "movq %'s0, %'d0", src=m1, dst=tigerframe.rax} )
				val _ = emit(OPER{assem = "cqto", src=[tigerframe.rax], dst=[tigerframe.rdx], jump = NONE})
				val _ = emit(OPER{assem = "idivq %'s2", src = [tigerframe.rax, tigerframe.rdx, m2], dst = [tigerframe.rax, tigerframe.rdx], jump = NONE}); 
				val _ = emit(MOV{assem = "movq %'s0, %'d0", src=tigerframe.rax, dst=r})
			in
				()
			end))
		| munchExp exp = raise Fail "Casos no cubiertos en tigercodegen.munchExp"
	    and munchStm (SEQ (a,b)) = (munchStm a; munchStm b)
        | munchStm (MOVE (MEM e1, e2)) = emit(OPER{assem = "movq %'s0, (%'s1)", src=[munchExp e2,munchExp e1],dst=[],jump=NONE})
	    | munchStm (MOVE(TEMP l, e))  = emit (MOV{assem="movq %'s0, %'d0", src=munchExp e, dst=l})
	    | munchStm (LABEL lab) = emit (aLABEL{assem = (makeString lab) ^ ":", lab=lab })
        | munchStm (JUMP (NAME l, [lp])) = if l <> lp then raise Fail "jump que no salta al nombre de su etiqueta 23987\n" else 
            emit(OPER{assem="jmp 'j0", src=[], dst=[], jump=SOME [l]})
        | munchStm (JUMP _) = raise Fail "jump invalido 98798\n"
        | munchStm (CJUMP (rop, e1, e2, l1, l2)) =
(*ojo que tal vez el cmp tiene los argumentos al reves*)
			(emit(OPER{assem = "cmpq %'s0, %'s1", src=[munchExp e2, munchExp e1], dst=[], jump=NONE});
            emit(OPER{assem = (salto rop) ^ " 'j0", src = [], dst = [], jump = SOME [l1,l2]}))
        | munchStm (EXP (CALL (NAME lab,args))) = 
			let (* val _ = emit(OPER{assem="xorq %'d0, %'d0", src=[], dst=[tigerframe.rax], jump=NONE}) (*Hace falta?? d0 no debia tener sempre 0?*)
				*)
			    val spoffset = (List.length args - List.length tigerframe.argregs) * tigerframe.wSz (* vamos a recuperar el sp en caso de haber hecho pushq antes del call*)
                val spoffset_aligned = ((spoffset+15) div 16) * 16 (* el stack tiene que estar alineado a 16 bytes *)
                val args' = if spoffset <> spoffset_aligned (* para respetar eso duplicamos el ultimo argumento en caso de ser necesario *)
                    then args @ [TEMP tigerframe.sp]
                    else args
                val srcArgs = munchArgs args'
				val _ =emit(OPER{assem="call "^(makeString lab), src=srcArgs, dst=tigerframe.calldefs, jump=NONE})
            in
				if spoffset>0
					then emit(OPER{assem = "addq $"^(toString spoffset_aligned)^", %'d0", src = [tigerframe.sp], dst = [tigerframe.sp], jump = NONE})
					else ()
				end
		| munchStm (EXP e) = (munchExp e ; ())
		| munchStm stm = raise Fail "Casos no cubiertos en tigercodegen.munchStm"
        and munchArgs zs =
            let
                fun consume_stack [] = []
                |   consume_stack (x::xs) = 
                    ( emit(OPER{assem = "pushq %'s0", src=[ munchExp x] , dst=[], jump=NONE}) ; consume_stack(xs) )
                fun consume_regs(_,[]) = []
                | consume_regs(r::rs,x::xs) =
                    ( emit(MOV{assem = "movq %'s0, %'d0", src=munchExp x, dst=r}) ; r :: consume_regs(rs,xs) )
                | consume_regs([], xs) =
                    consume_stack(List.rev(xs))
            in consume_regs (tigerframe.argregs, zs) end
    in
		munchStm stm;
		rev(!ilist)
	end

(*
codegens : tigerframe.frame -> tigertree.stm list -> tigerassem.instr list
*)
fun codegens frame stms = flatten (map (fn b => codegen frame b) stms)

end
