#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* This is a mini version of deb.c:deb_stack_all(). */
static void deb_stack(pTHX) {
#ifdef DC_DEBUGGING
  static const char * const si_names[] =
  {
   "UNKNOWN",
   "UNDEF",
   "MAIN",
   "MAGIC",
   "SORT",
   "SIGNAL",
    "OVERLOAD",
   "DESTROY",
   "WARNHOOK",
   "DIEHOOK",
   "REQUIRE"
  };
  char* const PL_block_type[] =
  {
   "NULL",
   "WHEN",
   "BLOCK",
   "GIVEN",
   "LOOP_FOR",
   "LOOP_PLAIN",
   "LOOP_LAZYSV",
   "LOOP_LAZYIV",
   "SUB",
   "FORMAT",
   "EVAL",
   "SUBST"
  };
  const PERL_SI *si = PL_curstackinfo;
  int siix;
  while (si->si_prev) {
    si = si->si_prev;
  }
  for (siix = 0; si; si = si->si_next, siix++) {
    I32 cxix;
    Perl_warn(aTHX_ "stack %d type %s(%d) %p\n",
              siix, si_names[si->si_type + 1], si->si_type, si);
    for (cxix = 0; cxix <= si->si_cxix; cxix++) {
      const PERL_CONTEXT* const cx = &(si->si_cxstack[cxix]);
      Perl_warn(aTHX_ "\tcx %d type %s(%d)\n",
                cxix, PL_block_type[CxTYPE(cx)], CxTYPE(cx));
    }
    if (si == PL_curstackinfo) {
      break;
    }
  }
#else
  PERL_UNUSED_CONTEXT;
#endif
}

static I32
dopoptoeval_in_package(pTHX_ I32 startingblock, SV *package_name)
{
    I32 i, optype;
    HEK *stash_hek;
    SV *tmpstr;
#ifdef DC_DEBUGGING
    Perl_warn(aTHX_ "dopoptoeval_in_package %d <%s> si_type %ld\n",
              startingblock, SvPV_nolen(package_name),
              (long)PL_curstackinfo->si_type);
#endif
    for (i = startingblock; i >= 0; i--) {
        const PERL_CONTEXT *cx = &cxstack[i];
        switch (CxTYPE(cx)) {
        default:
            continue;
        case CXt_EVAL:
            /* perl's S_dopoptoeval returns i unconditionally;
             * here we test for the current package name instead */
            stash_hek = SvTYPE(CopSTASH(cx->blk_oldcop)) == SVt_PVHV
                ? HvNAME_HEK((HV*)CopSTASH(cx->blk_oldcop))
                : NULL;
            if (stash_hek)
                Perl_sv_sethek(aTHX_ (tmpstr = sv_newmortal()), stash_hek);
#ifdef DC_DEBUGGING
            Perl_warn(aTHX_ "Found eval in <%s> cxix %d\n",
                      stash_hek ? SvPV_nolen(tmpstr) : "undef", i);
#endif
            if (Perl_sv_eq_flags(aTHX_ tmpstr, package_name, 0)) {
#ifdef DC_DEBUGGING
                Perl_warn(aTHX_ "Found package <%s> cxix %d\n",
                          SvPV_nolen(package_name), i);
#endif
                return i;
            }
        }
    }
#ifdef DC_DEBUGGING
    Perl_warn(aTHX_ "Not found package <%s> cxix %ld\n",
              SvPV_nolen(package_name), (long)i);
#endif
    return i;
}

MODULE = Die::Ception PACKAGE = Die::Ception

PROTOTYPES: DISABLE

void
die_until_package(package_name, msv)
    SV *package_name
    SV *msv
  CODE:
    /* the same thing than die_unwind, but until the desired scope is reached */
    if (PL_in_eval) {
        SV *exceptsv = sv_mortalcopy(msv);
        U8 in_eval = PL_in_eval;
	I32 cxix;
	I32 gimme;
	if (!(in_eval & EVAL_KEEPERR)) {
	    SvTEMP_off(exceptsv);
	    sv_setsv(ERRSV, exceptsv);
	}

	if (in_eval & EVAL_KEEPERR) {
	    Perl_ck_warner(aTHX_ packWARN(WARN_MISC), "\t(in cleanup) %"SVf,
			   SVfARG(exceptsv));
	}
#ifdef DC_DEBUGGING
        deb_stack(aTHX);
#endif
	while ((cxix = dopoptoeval_in_package(aTHX_ cxstack_ix, package_name)) < 0
	       && PL_curstackinfo->si_prev)
	{
#ifdef DC_DEBUGGING
            Perl_warn(aTHX_ "dounwind until empty\n");
#endif
	    dounwind(-1);
#ifdef DC_DEBUGGING
            Perl_warn(aTHX_ "popstack\n");
#endif
	    POPSTACK;
#ifdef DC_DEBUGGING
            deb_stack(aTHX);
#endif
	}
#ifdef DC_DEBUGGING
        deb_stack(aTHX);
#endif

	if (cxix >= 0) {
	    I32 optype;
	    SV *namesv;
	    PERL_CONTEXT *cx;
	    SV **newsp;
	    JMPENV *restartjmpenv;
	    OP *restartop;

	    if (cxix < cxstack_ix) {
#ifdef DC_DEBUGGING
                Perl_warn(aTHX_ "dounwind to cxix %ld si_type %ld\n", (long)cxix, (long)PL_curstackinfo->si_type);
#endif
		dounwind(cxix);
#ifdef DC_DEBUGGING
		deb_stack(aTHX);
#endif
            }

	    POPBLOCK(cx,PL_curpm);
	    if (CxTYPE(cx) != CXt_EVAL) {
		STRLEN msglen;
		const char* message = SvPVx_const(exceptsv, msglen);
		PerlIO_write(Perl_error_log, (const char *)"panic: die ", 11);
		PerlIO_write(Perl_error_log, message, msglen);
		my_exit(1);
	    }
	    POPEVAL(cx);
	    namesv = cx->blk_eval.old_namesv;
	    restartjmpenv = cx->blk_eval.cur_top_env;
	    restartop = cx->blk_eval.retop;

	    if (gimme == G_SCALAR)
		*++newsp = &PL_sv_undef;
	    PL_stack_sp = newsp;

	    LEAVE;

	    if (optype == OP_REQUIRE) {
                (void)hv_store(GvHVn(PL_incgv),
                               SvPVX_const(namesv),
                               SvUTF8(namesv) ? -(I32)SvCUR(namesv) : (I32)SvCUR(namesv),
                               &PL_sv_undef, 0);
		/* note that unlike pp_entereval, pp_require isn't
		 * supposed to trap errors. So now that we've popped the
		 * EVAL that pp_require pushed, and processed the error
		 * message, rethrow the error */
		Perl_croak(aTHX_ "%"SVf"Compilation failed in require",
			   SVfARG(exceptsv ? exceptsv : newSVpvs_flags("Unknown error\n",
                                                                    SVs_TEMP)));
	    }
	    if (!(in_eval & EVAL_KEEPERR))
		sv_setsv(ERRSV, exceptsv);
	    PL_restartjmpenv = restartjmpenv;
	    PL_restartop = restartop;
	    JMPENV_JUMP(3);
	    /* NOTREACHED */
	}
        else {
            /* package not found ? then die horribly, bypassing all evals */
            Perl_write_to_stderr(aTHX_ exceptsv);
            Perl_my_failure_exit(aTHX);
        }
    }
    else
        Perl_die_unwind(aTHX_ msv);
