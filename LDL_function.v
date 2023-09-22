From mathcomp Require Import all_ssreflect all_algebra.
From mathcomp Require Import lra.
From mathcomp Require Import order.
From mathcomp Require Import sequences reals exp.


Import Num.Def Num.Theory GRing.Theory.
Import Order.TTheory.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Inductive simple_type : Type :=
| Bool_T : simple_type
| Index_T : nat -> simple_type
| Real_T : simple_type
| Vector_T : nat -> simple_type
| Network_T : nat -> nat -> simple_type.

Inductive comparisons : Type :=
| le_E : comparisons
| lt_E : comparisons
| eq_E : comparisons
| neq_E : comparisons.

Inductive binary_logical : Type :=
| and_E : binary_logical
| or_E : binary_logical
| impl_E : binary_logical.

Variable R : realType.

Section expr.
Inductive expr : simple_type -> Type :=
  | Real : R -> expr Real_T
  | Bool : bool -> expr Bool_T
  | Index : forall n : nat, 'I_n -> expr (Index_T n)
  | Vector : forall n : nat, n.-tuple R -> expr (Vector_T n)

  (*logical connectives*)
  | binary_logical_E : binary_logical -> expr Bool_T -> expr Bool_T -> expr Bool_T
  | not_E : expr Bool_T -> expr Bool_T

  (*arithmetic operations*)
  | add_E : expr Real_T -> expr Real_T -> expr Real_T
  | mult_E : expr Real_T -> expr Real_T -> expr Real_T
  | minus_E : expr Real_T -> expr Real_T

  (*quantifiers - left for later consideration*)
  (*)| forall_E: forall t, expr t -> expr (Simple_T Bool_T)
  | exists_E: forall t, expr t -> expr (Simple_T Bool_T)*)

  (* networks and applications *)
  | net : forall n m : nat, (n.-tuple R -> m.-tuple R) -> expr (Network_T n m)
  | app_net : forall n m : nat, expr (Network_T n m) -> expr (Vector_T n) -> expr (Vector_T m)

  (*comparisons*)
  | comparisons_E : comparisons -> expr Real_T -> expr Real_T -> expr Bool_T
  (* | lookup_E v i: expr (Simple_T Vector_T) -> expr (Simple_T Index_T) -> expr (Simple_T Real_T) 
  I had this one before probably need to add this again, why did it get deleted?*)

  (*other - needed for DL translations*)
  | identity_E : expr Real_T -> expr Real_T -> expr Real_T.
End expr.

Notation "a /\ b" := (binary_logical_E and_E a b).
Notation "a \/ b" := (binary_logical_E or_E a b).
Notation "a `=> b" := (binary_logical_E impl_E a b) (at level 10).
Notation "`~ a" := (not_E a) (at level 10).
Notation "a `+ b" := (add_E a b) (at level 10).
Notation "a `* b" := (mult_E a b) (at level 10).
Notation "`- a" := (minus_E a) (at level 10).

Notation "a `<= b" := (comparisons_E le_E a b) (at level 10).
Notation "a `< b" := (comparisons_E lt_E a b) (at level 10).
Notation "a `>= b" := (comparisons_E le_E b a) (at level 10).
Notation "a `> b" := (comparisons_E lt_E b a) (at level 10).
Notation "a `== b" := (comparisons_E eq_E a b) (at level 10).
Notation "a `!= b" := (comparisons_E neq_E a b) (at level 10).
Notation "a `=== b" := (identity_E a b) (at level 10).
(* TODO: fix levels *)

(*currently for Łukasiewicz*)

Section translation_def.
Local Open Scope ring_scope.


Definition type_translation (t: simple_type) : Type:=
  match t with
  | Bool_T => R
  | Real_T => R
  | Vector_T n => n.-tuple R
  | Index_T n => 'I_n
  | Network_T n m => n.-tuple R -> m.-tuple R
end.

Inductive DL := Lukasiewicz | Yager.
Variable (l : DL).
Parameter (p : R).
Parameter (p1 : 1 <= p).

Definition translation_binop op a1 a2 :=
  match l with
  | Lukasiewicz =>
      match op with
      | and_E => maxr (a1 + a2 - 1) 0
      | or_E => minr (a1 + a2) 1
      | impl_E => minr (1 - a1 + a2) 1
      end
  | Yager =>
      match op with
      | and_E => maxr (1 - ((1 - a1) `^ p + (1 - a2) `^ p) `^ (p^-1)) 0
      | or_E => minr ((a1 `^ p + a2 `^ p) `^ (p^-1)) 1
      | impl_E => minr (((1 - a1) `^ p + a2 `^ p) `^ (p^-1)) 1
      end
  end.

Reserved Notation "[[ e ]]".
Fixpoint translation t (e: expr t) : type_translation t :=
    match e in expr t return type_translation t with
    | Bool true => (1%R : type_translation Bool_T)
    | Bool false => (0%R : type_translation Bool_T)
    | Real r => r%R
    | Index n i => i
    | Vector n t => t

    | binary_logical_E op E1 E2 => translation_binop op [[ E1 ]] [[ E2 ]]

    | `~ E1 => 1 - [[ E1 ]]

    (*simple arithmetic*)
    | E1 `+ E2 => [[ E1 ]] + [[ E2 ]]
    | E1 `* E2 => [[ E1 ]] * [[ E2 ]]
    | `- E1 => - [[ E1 ]]

    (*comparisons*)
    | E1 `== E2 => ([[ E1 ]] == [[ E2 ]])%:R(* 1 - `|([[ E1 ]] - [[ E2 ]]) / ([[ E1 ]] + [[ E2 ]])| *)
    | E1 `<= E2 => maxr (1 - maxr (([[ E1 ]] - [[ E2 ]]) / ([[ E1 ]] + [[ E2 ]])) 0) 0
    | E1 `!= E2 => 1 - ([[ E1 ]] == [[ E2 ]])%:R
    | E1 `< E2 => maxr 
      (maxr ((1 - maxr (([[ E1 ]] - [[ E2 ]]) / ([[ E1 ]] + [[ E2 ]])) 0)
        + ([[ E1 ]] != [[ E2 ]])%:R - 1) 0)
      0 
    | identity_E E1 E2 => ([[ E1 ]] == [[ E2 ]])%:R

    | net n m f => f
    | app_net n m f v => [[ f ]] [[ v ]]
    end
where "[[ e ]]" := (translation e).

End translation_def.

Notation "[[ e ]]_ l" := (translation l e) (at level 10).


Section translation_lemmas.
Local Open Scope ring_scope.

Parameter (l : DL).

Lemma andC e1 e2 :
  [[ e1 /\ e2 ]]_l = [[ e2 /\ e1 ]]_l.
Proof.
case: l.
- by rewrite /= (addrC (_ e1)).
- by rewrite /= (addrC (_ `^ _)).
Qed.

Lemma orC e1 e2 :
  [[ e1 \/ e2 ]]_l = [[ e2 \/ e1 ]]_l.
Proof.
case: l.
- by rewrite /= (addrC (_ e1)).
- by rewrite /= (addrC (_ `^ _)).
Qed.
Require Import Coq.Program.Equality.

Local Open Scope order_scope.
Lemma translate_Bool_T_01 (e : expr Bool_T) :
  0 <= [[ e ]]_l <= 1.
Proof.
dependent induction e => //=.
- by case: ifPn => //; lra.
- have := IHe1 e1 erefl JMeq_refl.
  have := IHe2 e2 erefl JMeq_refl.
  set t1 := _ e1.
  set t2 := _ e2.
  case: l => /= t2_01 t1_01.
  + case: b.
    * rewrite /maxr; case: ifP; lra.
    * rewrite /minr; case: ifP; lra.
    * rewrite /minr; case: ifP; lra.
  + case: b.
    * rewrite /maxr; case: ifP=>h1; first lra.
      apply/andP; split; last by rewrite cprD oppr_le0 powR_ge0.
      lra.
    have := IHe1 e1 erefl JMeq_refl.
    rewrite -/t1 => ?.
    have := IHe2 e2 erefl JMeq_refl.
    rewrite -/t2 => ?.
    have [t1t2|t1t2] := lerP ((t1 `^ p + t2 `^ p) `^ p^-1) 1.
      apply/andP; split. 
        by rewrite powR_ge0. 
    lra.
    lra.
  + have [t1t2|t1t2] := lerP (t1 + t2) 1.
    have := IHe1 e1 erefl JMeq_refl.
    rewrite -/t1 => ?.
    have := IHe2 e2 erefl JMeq_refl.
    rewrite -/t2 => ?.
    have [t1t2'|t1t2'] := lerP (((1 - t1) `^ p + t2 `^ p) `^ p^-1) 1.
      apply/andP; split.
        by rewrite powR_ge0. 
        lra.
  + lra.
    have [t1t2'|t1t2'] := lerP (((1 - t1) `^ p + t2 `^ p) `^ p^-1) 1.
    apply/andP; split.
        by rewrite powR_ge0. 
        lra.
       lra.
    apply/andP; split. 

(*   + have [t1t2|] := lerP (1 - t1 + t2) 1.
    have := IHe1 e1 erefl JMeq_refl.
    rewrite -/t1 => ?.
    have := IHe2 e2 erefl JMeq_refl.
    rewrite -/t2 => ?.
    lra.
    have := IHe1 e1 erefl JMeq_refl.
    rewrite -/t1 => ?.
    have := IHe2 e2 erefl JMeq_refl.
    rewrite -/t2 => ?.
    lra. *)
- set t := _ e.
    have := IHe e erefl JMeq_refl.
    rewrite -/t => ?.
    lra.
- set t := _ e.
    have := IHe e erefl JMeq_refl.
    rewrite -/t => ?.
    lra.
  set t1 := _ e1.
  set t2 := _ e2.
  case: c => //.
  + have [t1t2|t1t2] := ltrP ((t1 - t2) / (t1 + t2)) 0. 
      have [t0|t0] := ltrP (1-0) 0; lra. 
    apply/andP; split.
    have [t1t2'|t1t2'] := ltrP (1 - (t1 - t2) / (t1 + t2)) 0.
      lra. 
      rewrite subr_ge0. lra.
        have [t1t2'|t1t2'] := ltrP (1 - (t1 - t2) / (t1 + t2)) 0; lra.
  + have [t1t2|t1t2] := lerP ((t1 - t2) / (t1 + t2)) 0.

      have [t1t2'|t1t2'] := ltrP (1 - 0 + (t1 != t2)%:R - 1) 0. 
        have [t0|t0] := lerP 0 0. 
          by rewrite ler01 Bool.andb_true_r.
          by rewrite ler01 Bool.andb_true_r.
        have [t1t2''|t1t2''] := lerP (1 - 0 + (t1 != t2)%:R - 1) 0. 
          by rewrite ler01 Bool.andb_true_r. rewrite t1t2'.  rewrite andTb. 
          case:eqP =>/=. by rewrite addr0 subr0 subrr ler01. 
          by rewrite subr0 -addrA subrr addr0. 
    have [t1t2'|t1t2'] := lerP (1 - (t1 - t2) / (t1 + t2) + (t1 != t2)%:R - 1) 0.
      have [t0|t0] := lerP 0 0. 
          by rewrite ler01 Bool.andb_true_r.
          by rewrite ler01 Bool.andb_true_r.
      have [t1t2''|t1t2''] := lerP (1 - (t1 - t2) / (t1 + t2) + (t1 != t2)%:R - 1) 0.
        by rewrite ler01 Bool.andb_true_r.
      case:eqP =>/=.
      by have [t0|t0] := lerP 0 0. 
      have [t0|t0] := lerP 0 0. by rewrite ler01. by rewrite ler01.
      rewrite/maxr/=. case: ifP. rewrite ler01. Search (?x <= ?x).
      have [t1t2'|t1t2'] := lerP (1 - maxr ((t1 - t2) / (t1 + t2)) 0 + (t1 != t2)%:R - 1) 0.
        lra.
        apply/andP; split.
        lra.
        case: eqP =>/=.
        rewrite addr0.  intros eq12. 
        have [t1t2''|t1t2''] := lerP ((t1 - t2) / (t1 + t2)) 0; lra.
        intros H.
        have [t1t2''|t1t2''] := lerP ((t1 - t2) / (t1 + t2)) 0; lra.
  + apply/andP; split; case:eqP =>/=; lra.
  + apply/andP; split. case:eqP =>/=; lra.
  + case:eqP =>/=; lra.
Qed.

Lemma orA e1 e2 e3 :
  [[ (e1 \/ (e2 \/ e3)) ]]_l = [[ ((e1 \/ e2) \/ e3) ]]_l.
Proof.
have := translate_Bool_T_01 e1.
have := translate_Bool_T_01 e2.
have := translate_Bool_T_01 e3.
case: l => /=.
set t1 := _ e1.
set t2 := _ e2.
set t3 := _ e3.
rewrite /minr.
case: ifP; case: ifP; case: ifP; case: ifP; lra.
set t1 := _ e1.
set t2 := _ e2.
set t3 := _ e3.
admit.
Admitted.


Theorem associativity_and (B1 B2 B3: expr Bool_T) :
[[ (B1 /\ B2) /\ B3]] = [[ B1 /\ (B2 /\ B3) ]].
Proof.
rewrite /=.
set t1 := _ B1.
set t2 := _ B2.
set t3 := _ B3.
simpl in *.
have t101 : 0 <= t1 <= 1 := translate_Bool_T_01 B1.
have t201 : 0 <= t2 <= 1 := translate_Bool_T_01 B2.
have t301 : 0 <= t3 <= 1 := translate_Bool_T_01 B3.
have [t1t2|t1t2] := lerP (t1 + t2 - 1) 0.
  rewrite add0r.
  have [t31|t31] := lerP (t3 - 1) 0.
    have [t2t3|t2t3] := lerP (t2 + t3 - 1) 0.
      rewrite addr0.
      by have [t10|t10] := lerP (t1 - 1) 0; lra.
    rewrite !addrA.
    by have [t1t2t3|t1t2t3] := lerP (t1 + t2 + t3 - 1 - 1) 0; lra.
  have [t2t3|t2t3] := lerP (t2 + t3 - 1) 0.
    rewrite addr0.
    by have [t10|t10] := lerP (t1 - 1) 0; lra.
  rewrite !addrA.
  by have [t1t2t3|t1t2t3] := ltrP (t1 + t2 + t3 - 1 - 1) 0; lra.

have [t23|t23] := ltrP (t2 + t3 - 1) 0.
have [t123|t123] := ltrP (t1 + maxr (t2 + t3 - 1) 0 - 1) 0.

have [t1t2t3|t1t2t3] := lerP (t1 + t2 - 1 + t3 - 1) 0.
rewrite addr0.
have [t1'|t1'] := ltrP (t1 - 1) 0. lra. lra.
rewrite addr0.
have [t1'|t1'] := ltrP (t1 - 1) 0. lra. lra.
have [t123'|t123'] := ltrP (t1 + t2 - 1 + t3 -1) 0. 
rewrite addr0.
have [t1'|t1'] := ltrP (t1 - 1) 0. lra. lra.
rewrite addr0.
have [t1'|t1'] := ltrP (t1 - 1) 0. lra. lra.
have [t1'|t1'] := ltrP (t1 + t2 - 1 + t3 - 1) 0.
have [t123'|t123'] := ltrP (t1 + (t2 + t3 - 1) - 1) 0. lra. lra.
have [t123'|t123'] := ltrP (t1 + (t2 + t3 - 1) - 1) 0. lra. lra.

Qed.

(*intros. simpl.
case: lerP.
intros H1.
case: lerP.*)

(* Search (?n:R + ?m:R = ?m:R + ?n:R). *)
(* Search ( 0 < ?m -> 0 != ?m). *)





(* Lemma commutativity_add : forall E1 E2,
  add_E' E1 E2 = add_E' E2 E1.
Admitted.

Lemma associativity_add : forall E1 E2 E3,
  add_E' (add_E' E1 E2) E3 = add_E' E1 (add_E' E2 E3).
Admitted.

Theorem commutativity_and : forall (E1 E2 : Expr (Simple_T Bool_T))  (B1 B2 : Expr (Simple_T Real_T)),
  (and_E' E1 E2 ===> B1) -> 
  (and_E' E2 E1 ===> B2) ->
  B1 = B2.
Proof.
  intros. inversion H. inversion H0. subst. dependent inversion H3. (*tbc after redoing into functional*)
  
Qed. *)
