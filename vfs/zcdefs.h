diff --git a/sys/sys/cdefs.h b/sys/sys/cdefs.h
index 333f0df534..5ba92e35b3 100644
--- a/sys/sys/cdefs.h
+++ b/sys/sys/cdefs.h
@@ -563,6 +563,12 @@
 	    __builtin_types_compatible_p(__typeof(expr), t), yes, no)
 #endif
 
+#undef __POSIX_VISIBLE
+#undef __XSI_VISIBLE
+#undef __BSD_VISIBLE
+#undef __ISO_C_VISIBLE
+#undef __EXT1_VISIBLE
+
 /*-
  * POSIX.1 requires that the macros we test be defined before any standard
  * header file is included.
@@ -584,66 +590,58 @@
  * Our macros begin with two underscores to avoid namespace screwage.
  */
 
-/* Deal with IEEE Std. 1003.1-1990, in which _POSIX_C_SOURCE == 1. */
-#if defined(_POSIX_C_SOURCE) && (_POSIX_C_SOURCE - 0) == 1
-#undef _POSIX_C_SOURCE		/* Probably illegal, but beyond caring now. */
-#define	_POSIX_C_SOURCE		199009
-#endif
-
-/* Deal with IEEE Std. 1003.2-1992, in which _POSIX_C_SOURCE == 2. */
-#if defined(_POSIX_C_SOURCE) && (_POSIX_C_SOURCE - 0) == 2
-#undef _POSIX_C_SOURCE
-#define	_POSIX_C_SOURCE		199209
-#endif
-
 /* Deal with various X/Open Portability Guides and Single UNIX Spec. */
 #ifdef _XOPEN_SOURCE
 #if _XOPEN_SOURCE - 0 >= 700
 #define	__XSI_VISIBLE		700
-#undef _POSIX_C_SOURCE
-#define	_POSIX_C_SOURCE		200809
+#define	__POSIX_VISIBLE		200809
 #elif _XOPEN_SOURCE - 0 >= 600
 #define	__XSI_VISIBLE		600
-#undef _POSIX_C_SOURCE
-#define	_POSIX_C_SOURCE		200112
+#define	__POSIX_VISIBLE		200112
 #elif _XOPEN_SOURCE - 0 >= 500
 #define	__XSI_VISIBLE		500
-#undef _POSIX_C_SOURCE
-#define	_POSIX_C_SOURCE		199506
+#define	__POSIX_VISIBLE		199506
+#elif _XOPEN_SOURCE - 0 >= 1
+#define	__XSI_VISIBLE		1
+#define	__POSIX_VISIBLE		199209
 #endif
 #endif
 
 /*
- * Deal with all versions of POSIX.  The ordering relative to the tests above is
- * important.
+ * Deal with all versions of POSIX.
  */
-#if defined(_POSIX_SOURCE) && !defined(_POSIX_C_SOURCE)
-#define	_POSIX_C_SOURCE		198808
-#endif
-#ifdef _POSIX_C_SOURCE
+#if defined(_POSIX_C_SOURCE) && !defined(__POSIX_VISIBLE)
 #if (_POSIX_C_SOURCE - 0) >= 200809
 #define	__POSIX_VISIBLE		200809
-#define	__ISO_C_VISIBLE		1999
 #elif (_POSIX_C_SOURCE - 0) >= 200112
 #define	__POSIX_VISIBLE		200112
-#define	__ISO_C_VISIBLE		1999
 #elif (_POSIX_C_SOURCE - 0) >= 199506
 #define	__POSIX_VISIBLE		199506
-#define	__ISO_C_VISIBLE		1990
 #elif (_POSIX_C_SOURCE - 0) >= 199309
 #define	__POSIX_VISIBLE		199309
-#define	__ISO_C_VISIBLE		1990
 #elif (_POSIX_C_SOURCE - 0) >= 199209
 #define	__POSIX_VISIBLE		199209
-#define	__ISO_C_VISIBLE		1990
 #elif (_POSIX_C_SOURCE - 0) >= 199009
 #define	__POSIX_VISIBLE		199009
-#define	__ISO_C_VISIBLE		1990
+#elif (_POSIX_C_SOURCE - 0) == 2
+#define	__POSIX_VISIBLE		199209
+#elif (_POSIX_C_SOURCE - 0) == 1
+#define	__POSIX_VISIBLE		199009
 #else
 #define	__POSIX_VISIBLE		198808
-#define	__ISO_C_VISIBLE		0
-#endif /* _POSIX_C_SOURCE */
+#endif
+#endif
+
+#if defined(__POSIX_VISIBLE)
+#if (__POSIX_VISIBLE - 0) >= 200112
+#define	__ISO_C_VISIBLE		1999
+#elif (__POSIX_VISIBLE - 0) >= 199009
+#define	__ISO_C_VISIBLE		1990
 #else
+#define	__ISO_C_VISIBLE		0
+#endif
+#endif
+
 /*-
  * Deal with _ANSI_SOURCE:
  * If it is defined, and no other compilation environment is explicitly
@@ -656,12 +654,19 @@
  * _POSIX_C_SOURCE, we will assume that it wants the broader compilation
  * environment (and in fact we will never get here).
  */
+#if !defined(__XSI_VISIBLE) && !defined(__POSIX_VISIBLE)
 #if defined(_ANSI_SOURCE)	/* Hide almost everything. */
 #define	__POSIX_VISIBLE		0
 #define	__XSI_VISIBLE		0
 #define	__BSD_VISIBLE		0
 #define	__ISO_C_VISIBLE		1990
 #define	__EXT1_VISIBLE		0
+#elif defined(_POSIX_SOURCE)	/* Localism to specify strict POSIX1 env. */
+#define	__POSIX_VISIBLE		198808
+#define	__XSI_VISIBLE		0
+#define	__BSD_VISIBLE		0
+#define	__ISO_C_VISIBLE		0
+#define	__EXT1_VISIBLE		0
 #elif defined(_C99_SOURCE)	/* Localism to specify strict C99 env. */
 #define	__POSIX_VISIBLE		0
 #define	__XSI_VISIBLE		0
