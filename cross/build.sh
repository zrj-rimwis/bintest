#!/bin/sh

#
# Copyright (c) 2019-2020 The DragonFly Project.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
# COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

set -e

# DragonFly BSD source tree location
P=/zzz/DragonFlyBSD

# set to non-empty to compile world in two steps (userland+toolchain)
PSPLITtoolchain=da

# set to non-empty to compile kernel in two steps (kernel+modules)
PSPLITmodules=da

# aplies only on DragonFly BSD
PHOSTbinutils="binutils227"

mkdir -p /tmp/dfly/obj
mkdir -p /tmp/dfly/cross
mkdir -p /tmp/dfly/cross/lib
mkdir -p /tmp/dfly/cross/simple/sys
mkdir -p /tmp/dfly/cross/simple/linux
mkdir -p /tmp/dfly/cross/compat/rpc
mkdir -p /tmp/dfly/cross/compat/sys
mkdir -p /tmp/dfly/cross/compat/linux
mkdir -p /tmp/dfly/cross/compat/inlined

prepare_compat() {
#
# DISCLAIMER:  DO *NOT* RUN AS *ROOT*
# these header shims are minimalized, cut down versions and
# not suitable for general use outside this script needs.
# For full versions refer to DragonFly BSD source code tree.
#

cat << 'EOF' > /tmp/dfly/cross/compat/sys/cdefs.h
#include_next <sys/cdefs.h>
#ifndef __packed  /* needed by citrus in mkscmapper */
#define __packed        __attribute__((__packed__))
#endif
#undef __always_inline
#define __always_inline __attribute__ ((__always_inline__))
#undef ____DECONST
#ifdef __UINTPTR_TYPE__
#define ____DECONST(type, var)    ((type)(__UINTPTR_TYPE__)(const void *)(var))
#else
#define ____DECONST(type, var)    ((type)(const void *)(var))
#endif
#undef __pacify
#ifndef NO_PACIFY_COMPILER
#define __pacify(...) __VA_ARGS__
#else
#define __pacify(...)
#endif
#undef ____unused
#define ____unused __pacify(__attribute__((__unused__)))
#undef __dead2
#undef __unused
#undef __DECONST
#ifdef PACIFY_UNUSED
#define __dead2    __pacify(__attribute__((__noreturn__)))
#define __unused   __pacify(__attribute__((__unused__)))
#define __DECONST(type, var) ____DECONST(type, var)
#else
#define __dead2
#define __unused
#define __DECONST(x, y) (y)
#endif
#undef __pure
#define __pure
#undef __printflike
#define __printflike(...)
#undef __printf0like
#define __printf0like(...)
#undef __FBSDID
#define __FBSDID(s) struct hack
#undef __RCSID
#define __RCSID(s) struct hack
#undef __COPYRIGHT
#define __COPYRIGHT(s) struct hack
#ifdef __linux__
#undef __extern_always_inline
#define __extern_always_inline \
  extern inline __always_inline __attribute__((__gnu_inline__))
#endif
EOF
cp /tmp/dfly/cross/compat/sys/cdefs.h /tmp/dfly/cross/simple/sys/cdefs.h

cat << 'EOF' > /tmp/dfly/cross/compat/sys/param.h
#ifndef __compat_sys_param_h__
#define __compat_sys_param_h__
#include_next <sys/param.h>
#if !defined(__DragonFly__) || !defined(__FreeBSD__)
#ifndef rounddown2
#define rounddown2(x, y) ((x) & ~((y) - 1))
#endif
#ifndef roundup2  /* needed for citrus in mkcsmapper */
#define roundup2(x, y)  (((x)+((y)-1))&(~((y)-1)))
#endif
#ifndef NELEM
#define NELEM(ary)      (sizeof(ary) / sizeof((ary)[0]))
#endif
#ifdef __linux__
#include <sys/sysmacros.h> /* needed for makedev() minor() */
#endif
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/sys/mman.h
#ifndef __compat_sys_mman_h__
#define __compat_sys_mman_h__
#include_next <sys/mman.h>
#if defined(__linux__) || defined(__OpenBSD__) || defined(__NetBSD__)
#define MAP_NOCORE 0x0
#define MAP_NOSYNC 0x0
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/a.out.h
#ifndef __compat_a_out_h__
#define __compat_a_out_h__
#ifdef AOUT_H_FORCE32  /* for btxld.c */
#include <arpa/inet.h>
#include <stdint.h>
#ifndef roundup2  /* XXX for btxld.nx */
#define roundup2(x, y)  (((x)+((y)-1))&(~((y)-1)))
#endif
#define __LDPGSZ        4096 /* from sys/cpu/x86_64/include/exec.h */
#define N_GETMAGIC(ex) \
        ( (ex).a_midmag & 0xffff )
#define N_GETMAGIC_NET(ex) \
        (ntohl((ex).a_midmag) & 0xffff)
#define N_SETMAGIC(ex,mag,mid,flag) \
        ( (ex).a_midmag = (((flag) & 0x3f) <<26) | (((mid) & 0x03ff) << 16) | \
        ((mag) & 0xffff) )
#define N_ALIGN(ex,x) \
        (N_GETMAGIC(ex) == ZMAGIC || N_GETMAGIC(ex) == QMAGIC || \
         N_GETMAGIC_NET(ex) == ZMAGIC || N_GETMAGIC_NET(ex) == QMAGIC ? \
         ((x) + __LDPGSZ - 1) & ~(unsigned long)(__LDPGSZ - 1) : (x))
#define N_BADMAG(ex) \
        (N_GETMAGIC(ex) != OMAGIC && N_GETMAGIC(ex) != NMAGIC && \
         N_GETMAGIC(ex) != ZMAGIC && N_GETMAGIC(ex) != QMAGIC && \
         N_GETMAGIC_NET(ex) != OMAGIC && N_GETMAGIC_NET(ex) != NMAGIC && \
         N_GETMAGIC_NET(ex) != ZMAGIC && N_GETMAGIC_NET(ex) != QMAGIC)
typedef uint32_t       aout_register_t;
struct exec {
     aout_register_t    a_midmag;
     aout_register_t    a_text;
     aout_register_t    a_data;
     aout_register_t    a_bss;
     aout_register_t    a_syms;
     aout_register_t    a_entry;
     aout_register_t    a_trsize;
     aout_register_t    a_drsize;
};
#define OMAGIC          0407
#define NMAGIC          0410
#define ZMAGIC          0413
#define QMAGIC          0314
#define MID_ZERO        0
#else
#include_next <a.out.h>
#endif
#endif
EOF
cp /tmp/dfly/cross/compat/a.out.h /tmp/dfly/cross/simple/a.out.h

cat << 'EOF' > /tmp/dfly/cross/compat/sys/elf32.h
#ifndef __compat_sys_elf32_h__
#define __compat_sys_elf32_h__
#ifdef __DragonFly__
#include_next <sys/elf32.h>
#else
#include <stdint.h>

#define EI_MAG0         0
#define EI_MAG1         1
#define EI_MAG2         2
#define EI_MAG3         3
#define ELFMAG0         0x7f
#define ELFMAG1         'E'
#define ELFMAG2         'L'
#define ELFMAG3         'F'
#define IS_ELF(ehdr)    ((ehdr).e_ident[EI_MAG0] == ELFMAG0 && \
                         (ehdr).e_ident[EI_MAG1] == ELFMAG1 && \
                         (ehdr).e_ident[EI_MAG2] == ELFMAG2 && \
                         (ehdr).e_ident[EI_MAG3] == ELFMAG3)

#define ELFCLASS32      1
#define ELFDATA2LSB     1
#define EV_CURRENT      1

#define ET_EXEC         2
#define EM_386          3

#define SHN_UNDEF       0
#define SHT_NULL        0
#define SHT_PROGBITS    1
#define SHT_STRTAB      3
#define SHF_WRITE       0x1
#define SHF_ALLOC       0x2
#define SHF_EXECINSTR   0x4

#define PT_LOAD         1
#define PF_X            0x1
#define PF_W            0x2
#define PF_R            0x4

#if 1
typedef uint32_t Elf32_Addr;
typedef uint16_t Elf32_Half;
typedef uint32_t Elf32_Off;
typedef int32_t  Elf32_Sword;
typedef uint32_t Elf32_Word;
typedef uint32_t Elf32_Size;
typedef Elf32_Off Elf32_Hashelt;

typedef struct {
 unsigned char e_ident[16];
 Elf32_Half e_type;
 Elf32_Half e_machine;
 Elf32_Word e_version;
 Elf32_Addr e_entry;
 Elf32_Off e_phoff;
 Elf32_Off e_shoff;
 Elf32_Word e_flags;
 Elf32_Half e_ehsize;
 Elf32_Half e_phentsize;
 Elf32_Half e_phnum;
 Elf32_Half e_shentsize;
 Elf32_Half e_shnum;
 Elf32_Half e_shstrndx;
} Elf32_Ehdr;

typedef struct {
 Elf32_Word sh_name;
 Elf32_Word sh_type;
 Elf32_Word sh_flags;
 Elf32_Addr sh_addr;
 Elf32_Off sh_offset;
 Elf32_Size sh_size;
 Elf32_Word sh_link;
 Elf32_Word sh_info;
 Elf32_Size sh_addralign;
 Elf32_Size sh_entsize;
} Elf32_Shdr;

typedef struct {
 Elf32_Word p_type;
 Elf32_Off p_offset;
 Elf32_Addr p_vaddr;
 Elf32_Addr p_paddr;
 Elf32_Size p_filesz;
 Elf32_Size p_memsz;
 Elf32_Word p_flags;
 Elf32_Size p_align;
} Elf32_Phdr;
#endif
#endif
#endif
EOF
cp /tmp/dfly/cross/compat/sys/elf32.h /tmp/dfly/cross/simple/sys/elf32.h

cat << 'EOF' > /tmp/dfly/cross/compat/sys/elf64.h
#ifndef __compat_sys_elf64_h__
#define __compat_sys_elf64_h__
#ifdef __DragonFly__
#include_next <sys/elf64.h>
#else
#include <stdint.h>
#define EI_MAG0         0
#define EI_MAG1         1
#define EI_MAG2         2
#define EI_MAG3         3
#define EI_DATA         5
#define ELFMAG0         0x7f
#define ELFMAG1         'E'
#define ELFMAG2         'L'
#define ELFMAG3         'F'
#define IS_ELF(ehdr)    ((ehdr).e_ident[EI_MAG0] == ELFMAG0 && \
                         (ehdr).e_ident[EI_MAG1] == ELFMAG1 && \
                         (ehdr).e_ident[EI_MAG2] == ELFMAG2 && \
                         (ehdr).e_ident[EI_MAG3] == ELFMAG3)

#define ELFDATA2LSB     1
#define ELFDATA2MSB     2
#define EM_386          3
#define EM_ALPHA        0x9026
#define SHN_UNDEF       0
#define SHT_SYMTAB      2
#define SHT_STRTAB      3

#if 1
typedef uint64_t Elf64_Addr;
typedef uint16_t Elf64_Half;
typedef uint64_t Elf64_Off;
typedef int32_t Elf64_Sword;
typedef int64_t Elf64_Sxword;
typedef uint32_t Elf64_Word;
typedef uint64_t Elf64_Lword;
typedef uint64_t Elf64_Xword;
typedef Elf64_Word Elf64_Hashelt;
typedef Elf64_Xword Elf64_Size;
typedef Elf64_Sxword Elf64_Ssize;

typedef struct {
 unsigned char e_ident[16];
 Elf64_Half e_type;
 Elf64_Half e_machine;
 Elf64_Word e_version;
 Elf64_Addr e_entry;
 Elf64_Off e_phoff;
 Elf64_Off e_shoff;
 Elf64_Word e_flags;
 Elf64_Half e_ehsize;
 Elf64_Half e_phentsize;
 Elf64_Half e_phnum;
 Elf64_Half e_shentsize;
 Elf64_Half e_shnum;
 Elf64_Half e_shstrndx;
} Elf64_Ehdr;

typedef struct {
 Elf64_Word sh_name;
 Elf64_Word sh_type;
 Elf64_Xword sh_flags;
 Elf64_Addr sh_addr;
 Elf64_Off sh_offset;
 Elf64_Xword sh_size;
 Elf64_Word sh_link;
 Elf64_Word sh_info;
 Elf64_Xword sh_addralign;
 Elf64_Xword sh_entsize;
} Elf64_Shdr;

typedef struct {
 Elf64_Word p_type;
 Elf64_Word p_flags;
 Elf64_Off p_offset;
 Elf64_Addr p_vaddr;
 Elf64_Addr p_paddr;
 Elf64_Xword p_filesz;
 Elf64_Xword p_memsz;
 Elf64_Xword p_align;
} Elf64_Phdr;

typedef struct {
 Elf64_Sxword d_tag;
 union {
  Elf64_Xword d_val;
  Elf64_Addr d_ptr;
 } d_un;
} Elf64_Dyn;

typedef struct {
 Elf64_Addr r_offset;
 Elf64_Xword r_info;
} Elf64_Rel;

typedef struct {
 Elf64_Addr r_offset;
 Elf64_Xword r_info;
 Elf64_Sxword r_addend;
} Elf64_Rela;

typedef struct {
 Elf64_Word st_name;
 unsigned char st_info;
 unsigned char st_other;
 Elf64_Half st_shndx;
 Elf64_Addr st_value;
 Elf64_Xword st_size;
} Elf64_Sym;

typedef struct {
 Elf64_Half vd_version;
 Elf64_Half vd_flags;
 Elf64_Half vd_ndx;
 Elf64_Half vd_cnt;
 Elf64_Word vd_hash;
 Elf64_Word vd_aux;
 Elf64_Word vd_next;
} Elf64_Verdef;

typedef struct {
 Elf64_Word vda_name;
 Elf64_Word vda_next;
} Elf64_Verdaux;

typedef struct {
 Elf64_Half vn_version;
 Elf64_Half vn_cnt;
 Elf64_Word vn_file;
 Elf64_Word vn_aux;
 Elf64_Word vn_next;
} Elf64_Verneed;

typedef struct {
 Elf64_Word vna_hash;
 Elf64_Half vna_flags;
 Elf64_Half vna_other;
 Elf64_Word vna_name;
 Elf64_Word vna_next;
} Elf64_Vernaux;

typedef Elf64_Half Elf64_Versym;
#endif

#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/sys/elf_generic.h
#ifndef __compat_sys_elf_generic_h__
#define __compat_sys_elf_generic_h__
#ifdef __DragonFly__
#include_next <sys/elf_generic.h>
#else
#include <sys/cdefs.h>
#include <endian.h>
#include <stdint.h>

#ifdef __ELF_WORD_SIZE

#if __ELF_WORD_SIZE != 32 && __ELF_WORD_SIZE != 64
#error "__ELF_WORD_SIZE must be defined as 32 or 64"
#endif

#if !defined(__LITTLE_ENDIAN) && !defined(_LITTLE_ENDIAN)
#error "not little endian???"
#endif

#if defined(__BYTE_ORDER)
#if (__BYTE_ORDER == __LITTLE_ENDIAN)
#define ELF_DATA        ELFDATA2LSB
#elif __BYTE_ORDER == __BIG_ENDIAN
#define ELF_DATA        ELFDATA2MSB
#endif
#elif defined(_BYTE_ORDER)
#if (_BYTE_ORDER == _LITTLE_ENDIAN)
#define ELF_DATA        ELFDATA2LSB
#elif _BYTE_ORDER == _BIG_ENDIAN
#define ELF_DATA        ELFDATA2MSB
#endif
#endif

#ifndef ELF_DATA
#error "Unknown byte order"
#endif

#if 0
#define ELF_CLASS       __CONCAT(ELFCLASS,__ELF_WORD_SIZE)
#define __elfN(x)       __CONCAT(__CONCAT(__CONCAT(elf,__ELF_WORD_SIZE),_),x)
#define __ElfN(x)       __CONCAT(__CONCAT(__CONCAT(Elf,__ELF_WORD_SIZE),_),x)
#define __ELFN(x)       __CONCAT(__CONCAT(__CONCAT(ELF,__ELF_WORD_SIZE),_),x)
#define __ElfType(x)    typedef __ElfN(x) __CONCAT(Elf_,x)
__ElfType(Off);
__ElfType(Shdr);
__ElfType(Ehdr);
#endif

#if __ELF_WORD_SIZE == 64
typedef Elf64_Addr Elf_Addr;
typedef Elf64_Half Elf_Half;
typedef Elf64_Off Elf_Off;
typedef Elf64_Sword Elf_Sword;
typedef Elf64_Word Elf_Word;
typedef Elf64_Ehdr Elf_Ehdr;
typedef Elf64_Shdr Elf_Shdr;
typedef Elf64_Phdr Elf_Phdr;
typedef Elf64_Dyn Elf_Dyn;
typedef Elf64_Rel Elf_Rel;
typedef Elf64_Rela Elf_Rela;
typedef Elf64_Sym Elf_Sym;
typedef Elf64_Verdef Elf_Verdef;
typedef Elf64_Verdaux Elf_Verdaux;
typedef Elf64_Verneed Elf_Verneed;
typedef Elf64_Vernaux Elf_Vernaux;
typedef Elf64_Versym Elf_Versym;
typedef Elf64_Hashelt Elf_Hashelt;
typedef Elf64_Size Elf_Size;
#endif
#endif
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/ncurses_cfg.h
#ifndef __compat_ncurses_cfg_h__
#define __compat_ncurses_cfg_h__
#include_next "ncurses_cfg.h"
#ifdef __linux__
#undef HAVE_BSD_CGETENT
#undef USE_GETCAP
#define HAVE_BSD_CGETENT 0
#define USE_GETCAP 0
#endif
#endif
EOF
cp /tmp/dfly/cross/compat/ncurses_cfg.h /tmp/dfly/cross/simple/ncurses_cfg.h

cat << 'EOF' > /tmp/dfly/cross/compat/sys/endian.h
#ifndef __compat_sys_endian_h__
#define __compat_sys_endian_h__
#ifdef __OpenBSD__
#define bswap32(x) swap32(x)
#endif
#ifdef __linux__
#include <endian.h>  /* XXX for strfile */
#define bswap32(x) __bswap_32(x)
#else
#include_next <sys/endian.h>
#endif
#endif
EOF
cp /tmp/dfly/cross/compat/sys/endian.h /tmp/dfly/cross/simple/sys/endian.h

cat << 'EOF' > /tmp/dfly/cross/compat/auto-host.h
#ifndef __compat_auto_host_h__
#define __compat_auto_host_h__
#include_next "auto-host.h"
#if defined(__OpenBSD__) || defined(__NetBSD__)
#undef HAVE_CLEARERR_UNLOCKED
#undef HAVE_FERROR_UNLOCKED
#undef HAVE_FEOF_UNLOCKED
#undef HAVE_FILENO_UNLOCKED
#endif
#endif
EOF
cp /tmp/dfly/cross/compat/auto-host.h /tmp/dfly/cross/simple/auto-host.h

cat << 'EOF' > /tmp/dfly/cross/compat/fnmatch.h
#ifndef __compat_fnmatch_h__
#define __compat_fnmatch_h__
#include_next <fnmatch.h>
#if defined(__NetBSD__) /* XXX libiberty */
#define FNM_FILE_NAME FNM_PATHNAME
#endif
#endif
EOF
cp /tmp/dfly/cross/compat/fnmatch.h /tmp/dfly/cross/simple/fnmatch.h

cat << 'EOF' > /tmp/dfly/cross/compat/iconv.h
#ifndef __compat_iconv_h__
#define __compat_iconv_h__
#include <sys/cdefs.h>
#if defined(__OpenBSD__)
struct __tag_iconv_t;
typedef struct __tag_iconv_t    *iconv_t;
#else
#include_next <iconv.h>
#endif
#endif
EOF
cp /tmp/dfly/cross/compat/iconv.h /tmp/dfly/cross/simple/iconv.h

cat << 'EOF' > /tmp/dfly/cross/simple/clocale
#ifndef __compat_clocale__
#define __compat_clocale__
#include_next <clocale>
#ifdef SYSTEM_H
#ifdef _LIBCPP_VERSION /* XXX contrib/binutils-2.27/gold/system.h */
#define HAVE_UNORDERED_SET 1
#define HAVE_UNORDERED_MAP 1
#endif
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/sys/procfs.h
#ifndef __compat_sys_procfs_h__
#define __compat_sys_procfs_h__
#include <sys/cdefs.h>
#if defined(__OpenBSD__) || defined(__NetBSD__)
#undef HAVE_PRSTATUS_T
#undef HAVE_PRPSINFO_T
#undef HAVE_PSINFO_T
#else
#include_next <sys/procfs.h>
#endif
#endif
EOF
cp /tmp/dfly/cross/compat/sys/procfs.h /tmp/dfly/cross/simple/sys/procfs.h

cat << 'EOF' > /tmp/dfly/cross/compat/sys/ttydev.h
#ifndef __compat_sys_ttydev_h__
#define __compat_sys_ttydev_h__
#ifdef __OpenBSD__
#include <sys/cdefs.h>
/* #include <sys/termios.h> */  /* for B75 etc */
#define B0      0
#define B50     50
#define B75     75
#define B110    110
#define B134    134
#define B150    150
#define B200    200
#define B300    300
#define B600    600
#define B1200   1200
#define B1800   1800
#define B2400   2400
#define B4800   4800
#define B9600   9600
#define B19200  19200
#define B38400  38400
#if __BSD_VISIBLE
#define B7200   7200
#define B14400  14400
#define B28800  28800
#define B57600  57600
#define B76800  76800
#define B115200 115200
#define B230400 230400
#define EXTA    19200
#define EXTB    38400
#endif /* __BSD_VISIBLE */
#else
#include_next <sys/ttydev.h>
#endif
#endif
EOF
cp /tmp/dfly/cross/compat/sys/ttydev.h /tmp/dfly/cross/simple/sys/ttydev.h

cat << 'EOF' > /tmp/dfly/cross/compat/sys/sysctl.h
#ifndef __compat_sys_sysctl_h__
#define __compat_sys_sysctl_h__
#include <sys/cdefs.h>
/* The <sys/sysctl.h> header is deprecated and will be removed." */
#ifndef __linux__
#include_next <sys/sysctl.h>
#endif
#endif
EOF
cp /tmp/dfly/cross/compat/sys/sysctl.h /tmp/dfly/cross/simple/sys/sysctl.h

cat << 'EOF' > /tmp/dfly/cross/compat/linux/sysctl.h
#ifndef __compat_linux_sysctl_h__
#define __compat_linux_sysctl_h__
#include <sys/cdefs.h>
#undef __unused
#include_next <linux/sysctl.h>
#define __unused
#endif
EOF
cp /tmp/dfly/cross/compat/linux/sysctl.h /tmp/dfly/cross/simple/linux/sysctl.h

cat << 'EOF' > /tmp/dfly/cross/compat/features.h
#ifndef __compat_linux_features_h__
#define __compat_linux_features_h__
#if defined(__linux__) && !defined(_GNU_SOURCE)
#define _GNU_SOURCE                   /* needed for asprintf() */
#define _DEFAULT_SOURCE
#endif
#include_next <features.h>
#undef __GLIBC_USE_DEPRECATED_GETS
#define __GLIBC_USE_DEPRECATED_GETS 1 /* expose gets() for grep */
#endif
EOF
cp /tmp/dfly/cross/compat/features.h /tmp/dfly/cross/simple/features.h

# do not wrap <limits.h>, include-fixed/limits.h stuff

cat << 'EOF' > /tmp/dfly/cross/compat/objformat.h
#ifndef __compat_objformat_h__
#define __compat_objformat_h__
#ifdef __DragonFly__
#include_next <objformat.h>
#else
#include <sys/cdefs.h>
#include <stddef.h>

static __inline __always_inline size_t
__obj_strlcpy(char *dst, const char *src, size_t siz){
  char *d = dst;
  const char *s = src;
  size_t n = siz;

  if (!dst || !src)
    return 0;
  if (n != 0 && --n != 0) {
    do {
      if ((*d++ = *s++) == 0)
        break;
    } while (--n != 0);
  }
  if (n == 0) {
    if (siz != 0)
      *d = '\0';
    while (*s++) ;
  }
  return(s - src - 1);
}

static __inline __always_inline int
getobjformat(char *buf, size_t buflen,
             int *argcp ____unused, char **argv ____unused)
{
  if (__obj_strlcpy(buf, "elf", buflen) >= buflen)
    return(-1);
  return(3);
}
#endif
#endif
EOF
cp /tmp/dfly/cross/compat/objformat.h /tmp/dfly/cross/simple/objformat.h

cat << 'EOF' > /tmp/dfly/cross/compat/resolv.h
#ifndef __compat_resolv_h__
#define __compat_resolv_h__
#include_next <resolv.h>
#ifdef __linux__
#include <inlined/resolv.hi> /* b64_ntop b64_pton */
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/paths.h
#ifndef __compat_paths_h__
#define __compat_paths_h__
#include_next <paths.h>
#ifndef _PATH_CP
#define _PATH_CP "/bin/cp"
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/fcntl.h
#ifndef __compat_fcntl_h__
#define __compat_fcntl_h__
#include_next <fcntl.h>
#ifdef __linux__
#include <sys/file.h> /* for flock() */
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/errno.h
#ifndef __compat_errno_h__
#define __compat_errno_h__
#include_next <errno.h>
#ifndef EFTYPE
#define EFTYPE 666
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/nl_types.h
#ifndef __compat_nl_types_h__
#define __compat_nl_types_h__
#include_next <nl_types.h>
#ifdef __linux__
#ifdef _NLS_PRIVATE
#include <stdint.h>
#define _NLS_MAGIC      0xff88ff89

struct _nls_cat_hdr {
  int32_t __magic;
  int32_t __nsets;
  int32_t __mem;
  int32_t __msg_hdr_offset;
  int32_t __msg_txt_offset;
} ;

struct _nls_set_hdr {
  int32_t __setno;
  int32_t __nmsgs;
  int32_t __index;
} ;

struct _nls_msg_hdr {
  int32_t __msgno;
  int32_t __msglen;
  int32_t __offset;
} ;
#endif
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/regex.h
#ifndef __compat_regex_h__
#define __compat_regex_h__
#include_next <regex.h>
#ifndef REG_BASIC
#define REG_BASIC 0
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/semaphore.h
#ifndef __compat_semaphore_h__
#define __compat_semaphore_h__
#include_next <semaphore.h>
/* Work around lack of semaphore support in libc without pthreads in sort(1) */
#if defined(__linux__) || defined(__OpenBSD__) || defined(__NetBSD__)
#if defined(WITHOUT_NLS)
#define sem_init(x, y, z)
#define sem_post(x)
#define sem_wait(x)
#endif
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/xlocale.h
#ifndef __compat_xlocale_h__
#define __compat_xlocale_h__
#if !defined(__linux__) && !defined(__OpenBSD__) && !defined(__NetBSD__)
#include_next <xlocale.h>
#endif
#ifdef __NetBSD__  /* XXX mkmagic.nx */
#undef HAVE_USELOCALE
#undef HAVE_NEWLOCALE
#endif
#endif
EOF
cp /tmp/dfly/cross/compat/xlocale.h /tmp/dfly/cross/simple/xlocale.h

cat << 'EOF' > /tmp/dfly/cross/compat/ctype.h
#ifndef __compat_ctype_h__
#define __compat_ctype_h__
#include_next <ctype.h>
#ifdef __NetBSD__  /* XXX localedef(1) */
#define _CTYPE_B     _CTYPE_BL
#define _CTYPE_SW0      0x20000000L
#define _CTYPE_SW1      0x40000000L
#define _CTYPE_SW2      0x80000000L
#define _CTYPE_SW3      0xc0000000L
#define _CTYPE_SWM      0xe0000000L
#define _CTYPE_SWS      30
#endif
#if defined(__linux__) || defined(__OpenBSD__)
#define _CTYPE_A        0x00000100L
#define _CTYPE_C        0x00000200L
#define _CTYPE_D        0x00000400L
#define _CTYPE_G        0x00000800L
#define _CTYPE_L        0x00001000L
#define _CTYPE_P        0x00002000L
#define _CTYPE_S        0x00004000L
#define _CTYPE_U        0x00008000L
#define _CTYPE_X        0x00010000L
#define _CTYPE_B        0x00020000L
#define _CTYPE_R        0x00040000L
#define _CTYPE_I        0x00080000L
#define _CTYPE_T        0x00100000L
#define _CTYPE_Q        0x00200000L
#define _CTYPE_N        0x00400000L
#define _CTYPE_SW0      0x20000000L
#define _CTYPE_SW1      0x40000000L
#define _CTYPE_SW2      0x80000000L
#define _CTYPE_SW3      0xc0000000L
#define _CTYPE_SWM      0xe0000000L
#define _CTYPE_SWS      30
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/wctype.h
#ifndef __compat_wctype_h__
#define __compat_wctype_h__
#include_next <wctype.h>
#if !defined(__DragonFly__) && !defined(__FreeBSD__)
#include <sys/cdefs.h>
/* #include <err.h> */
static inline __always_inline wint_t
nextwctype(wint_t wc, wctype_t wct)
{
  wint_t t;
  int i;
  if ((int)wc == -1) {/* best efforts, try search for first char in this case */
    for (i = 1; i < 4096; i++)
      if (iswctype(i, wct))
        break;
    t = i;
/*    warn("get i=%d", i); */
  } else {
    t = wc + 1;
  }
  if (iswctype(t, wct))
    return t;
  else
    return -1;
}
wint_t  iswrune(wint_t);
#define iswrune(wc)             1
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/rpc/types.h
#ifndef __compat_rpc_types_h__
#define __compat_rpc_types_h__
#ifndef __linux__
#include_next <rpc/types.h>
#endif
#ifdef __linux__
#include <stdint.h>
typedef int32_t bool_t;
#ifndef FALSE
#define FALSE    (0)
#endif
#ifndef TRUE
#define TRUE     (1)
#endif
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/libutil.h
#ifndef __compat_libutil_h__
#define __compat_libutil_h__
#ifdef __NetBSD__
#define HN_IEC_PREFIXES 0x0 /* XXX dd(1) misc.c */
#endif
#ifndef __NetBSD__
/* #include_next <libutil.h> */
#include <sys/types.h>
#include <assert.h>
#include <errno.h>
#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define FPARSELN_UNESCESC       0x01
#define FPARSELN_UNESCCONT      0x02
#define FPARSELN_UNESCCOMM      0x04
#define FPARSELN_UNESCREST      0x08
#define FPARSELN_UNESCALL       0x0f

static inline __always_inline int
__isescaped(const char *sp, const char *p, int esc)
{
  const char     *cp;
  size_t          ne;
  if (esc == '\0')
    return 0;
  for (ne = 0, cp = p; --cp >= sp && *cp == esc; ne++)
    continue;
  return (ne & 1) != 0;
}

static inline __always_inline char *
fparseln(FILE *fp, size_t *size, size_t *lineno, const char str[3], int flags)
{
  static const char dstr[3] = { '\\', '\\', '#' };
  ssize_t s;
  size_t len, ptrlen;
  char   *buf;
  char   *ptr, *cp;
  int     cnt;
  char    esc, con, nl, com;
  len = 0;
  buf = NULL;
  ptrlen = 0;
  ptr = NULL;
  cnt = 1;
  if (str == NULL)
    str = dstr;
  esc = str[0];
  con = str[1];
  com = str[2];
  nl  = '\n';
  flockfile(fp);
  while (cnt) {
    cnt = 0;
    if (lineno)
      (*lineno)++;
    s = getline(&ptr, &ptrlen, fp);
    if (s < 0)
      break;
    if (s && com) {
      for (cp = ptr; cp < ptr + s; cp++)
        if (*cp == com && !__isescaped(ptr, cp, esc)) {
          s = cp - ptr;
          cnt = s == 0 && buf == NULL;
          break;
        }
    }
    if (s && nl) {
      cp = &ptr[s - 1];
      if (*cp == nl)
        s--;
    }
    if (s && con) {
      cp = &ptr[s - 1];
      if (*cp == con && !__isescaped(ptr, cp, esc)) {
        s--;
        cnt = 1;
      }
    }
    if (s == 0) {
      if (cnt || buf != NULL)
        continue;
    }
    if ((cp = realloc(buf, len + s + 1)) == NULL) {
      funlockfile(fp);
      free(buf);
      free(ptr);
      return NULL;
    }
    buf = cp;
    (void) memcpy(buf + len, ptr, s);
    len += s;
    buf[len] = '\0';
  }
  funlockfile(fp);
  free(ptr);
  if ((flags & FPARSELN_UNESCALL) != 0 && esc && buf != NULL &&
      strchr(buf, esc) != NULL) {
    ptr = cp = buf;
    while (cp[0] != '\0') {
      int skipesc;
      while (cp[0] != '\0' && cp[0] != esc)
        *ptr++ = *cp++;
      if (cp[0] == '\0' || cp[1] == '\0')
        break;
      skipesc = 0;
      if (cp[1] == com)
        skipesc += (flags & FPARSELN_UNESCCOMM);
      if (cp[1] == con)
        skipesc += (flags & FPARSELN_UNESCCONT);
      if (cp[1] == esc)
        skipesc += (flags & FPARSELN_UNESCESC);
      if (cp[1] != com && cp[1] != con && cp[1] != esc)
        skipesc = (flags & FPARSELN_UNESCREST);
      if (skipesc)
        cp++;
      else
        *ptr++ = *cp++;
      *ptr++ = *cp++;
    }
    *ptr = '\0';
    len = strlen(buf);
  }
  if (size)
    *size = len;
  return buf;
}

#define HN_DECIMAL              0x01
#define HN_NOSPACE              0x02
#define HN_B                    0x04
#define HN_DIVISOR_1000         0x08
#define HN_IEC_PREFIXES         0x10
#define HN_FRACTIONAL           0x20
#define HN_GETSCALE             0x10
#define HN_AUTOSCALE            0x20

static inline __always_inline int
humanize_number(char *buf, size_t len, int64_t quotient,
    const char *suffix, int scale, int flags)
{
  const char *prefixes, *sep;
  int     i, r, remainder, s1, s2, sign;
  int     divisordeccut;
  int64_t divisor, max;
  size_t  baselen;
  if (len > 0)
    buf[0] = '\0';
  if (buf == NULL || suffix == NULL)
    return (-1);
  if (scale < 0)
    return (-1);
  else if (scale >= 7 /*maxscale*/ && ((scale & ~(HN_AUTOSCALE|HN_GETSCALE)) != 0))
    return (-1);
  if ((flags & HN_DIVISOR_1000) && (flags & HN_IEC_PREFIXES))
    return (-1);
  remainder = 0;
  if (flags & HN_IEC_PREFIXES) {
    baselen = 2;
    divisor = 1024;
    divisordeccut = 973;
    if (flags & HN_B)
      prefixes = "B\0\0Ki\0Mi\0Gi\0Ti\0Pi\0Ei";
    else
      prefixes = "\0\0\0Ki\0Mi\0Gi\0Ti\0Pi\0Ei";
  } else {
    baselen = 1;
    if (flags & HN_DIVISOR_1000) {
      divisor = 1000;
      divisordeccut = 950;
      if (flags & HN_B)
        prefixes = "B\0\0k\0\0M\0\0G\0\0T\0\0P\0\0E";
      else
        prefixes = "\0\0\0k\0\0M\0\0G\0\0T\0\0P\0\0E";
    } else {
      divisor = 1024;
      divisordeccut = 973;
      if (flags & HN_B)
        prefixes = "B\0\0K\0\0M\0\0G\0\0T\0\0P\0\0E";
      else
        prefixes = "\0\0\0K\0\0M\0\0G\0\0T\0\0P\0\0E";
    }
  }
#define __HM_SCALE2PREFIX(scale)     (&prefixes[(scale) * 3])
  if (quotient < 0) {
    sign = -1;
    quotient = -quotient;
    baselen += 2;
  } else {
    sign = 1;
    baselen += 1;
  }
  if (flags & HN_NOSPACE)
    sep = "";
  else {
    sep = " ";
    baselen++;
  }
  baselen += strlen(suffix);
  if (len < baselen + 1)
    return (-1);
  if (scale & (HN_AUTOSCALE | HN_GETSCALE)) {
    for (max = 1, i = len - baselen; i-- > 0;)
      max *= 10;
    for (i = 0; (quotient >= max || (quotient == max - 1 &&
                 remainder >= divisordeccut)) && i < 7 /*maxscale*/; i++) {
      remainder = quotient % divisor;
      quotient /= divisor;
      }
    if (scale & HN_GETSCALE)
      return (i);
  } else {
    for (i = 0; i < scale && i < 7 /*maxscale*/; i++) {
      remainder = quotient % divisor;
      quotient /= divisor;
    }
  }
  r = snprintf(buf, len, "%" PRId64 "%s%s%s",
               sign * (quotient + (remainder + divisor / 2) / divisor),
               sep, __HM_SCALE2PREFIX(i), suffix);
  if ((flags & HN_FRACTIONAL) && (u_int)r + 3 <= len && i) {
    int64_t frac;
    int n;
    n = (int)len - r - 2;
    frac = 1;
    if (n > 2)
      n = 2;
    while (n) {
      frac = frac * 10;
      --n;
    }
    s1 = (int)quotient + ((remainder * frac + divisor / 2) / divisor / frac);
    s2 = ((remainder * frac + divisor / 2) / divisor) % frac;
    r = snprintf(buf, len, "%d%s%d%s%s%s", sign * s1, ".", s2,
                 sep, __HM_SCALE2PREFIX(i), suffix);
  } else if ((flags & HN_DECIMAL) && (u_int)r + 3 <= len &&
            (((quotient == 9 && remainder < divisordeccut) ||
               quotient < 9) && i > 0)) {
    s1 = (int)quotient + ((remainder * 10 + divisor / 2) / divisor / 10);
    s2 = ((remainder * 10 + divisor / 2) / divisor) % 10;
    r = snprintf(buf, len, "%d%s%d%s%s%s", sign * s1, ".", s2,
                 sep, __HM_SCALE2PREFIX(i), suffix);
  }
  return (r);
}
#undef __HM_SCALE2PREFIX
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/util.h
#ifndef __compat_util_h__
#define __compat_util_h__
#include <libutil.h>
#ifdef USE_EMALLOC /* for bmake emalloc shims */
#include_next "util.h"
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/wchar.h
#ifndef __compat_wchar_h__
#define __compat_wchar_h__
#if defined(__linux__) && defined(pacify_glibc_headers_GCC)
#include <features.h>
#endif
#if defined(__GLIBC__) && defined(pacify_glibc_headers_GCC)
#pragma GCC diagnostic push  /* we compile with -Wsystem-headers */
#pragma GCC diagnostic ignored "-Wredundant-decls"
#endif
#include_next <wchar.h>
#if defined(__GLIBC__) && defined(pacify_glibc_headers_GCC)
#pragma GCC diagnostic pop
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/assert.h
#ifndef __compat_assert_h__
#define __compat_assert_h__
#if defined(__linux__) && defined(pacify_glibc_headers_GCC)
#include <features.h>
#endif
#if defined(__GLIBC__) && defined(pacify_glibc_headers_GCC)
#pragma GCC diagnostic push  /* we compile with -Wsystem-headers */
#pragma GCC diagnostic ignored "-Wredundant-decls"
#endif
#include_next <assert.h>
#if defined(__GLIBC__) && defined(pacify_glibc_headers_GCC)
#pragma GCC diagnostic pop
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/stdio.h
#ifndef __compat_stdio_h__
#define __compat_stdio_h__
#if defined(__linux__) && defined(pacify_glibc_headers_GCC)
#undef _GL_WARN_ON_USE
#define _GL_WARN_ON_USE(function, message)
#include <features.h>
#endif
#if defined(__GLIBC__) && defined(pacify_glibc_headers_GCC)
#pragma GCC diagnostic push  /* we compile with -Wsystem-headers */
#pragma GCC diagnostic ignored "-Wredundant-decls"
#endif
#include_next <stdio.h>
#if defined(__GLIBC__) && defined(pacify_glibc_headers_GCC)
#pragma GCC diagnostic pop
#endif
#ifdef __linux__
#include <inlined/stdio.hi> /* fgetln funopen */
#endif
#if defined(__OpenBSD__) || defined(__NetBSD__)
static inline __always_inline ssize_t
__fpending(const FILE *fp)
{
  return(fp->_p - fp->_bf._base);
}
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/simple/stdlib.h
#ifndef __compat_stdlib_h__
#define __compat_stdlib_h__
#include_next <stdlib.h>
#ifdef __linux__
#include <sys/cdefs.h>
#include <errno.h>
#include <limits.h>
#include <stdint.h>

#define __INVALID         1
#define __TOOSMALL        2
#define __TOOLARGE        3

static inline __always_inline long long  /* XXX for games/boogle/mkdict */
strtonum(const char *numstr, long long minval, long long maxval,
    const char **errstrp)
{
  long long ll = 0;
  char *ep;
  int error = 0;
  struct errval {
    const char *errstr;
    int err;
  } ev[4] = {
    { NULL,         0 },
    { "invalid",    EINVAL },
    { "too small",  ERANGE },
    { "too large",  ERANGE },
  };
  ev[0].err = errno;
  errno = 0;
  if (minval > maxval)
    error = __INVALID;
  else {
    ll = strtoll(numstr, &ep, 10);
    if (numstr == ep || *ep != '\0')
      error = __INVALID;
    else if ((ll == LLONG_MIN && errno == ERANGE) || ll < minval)
      error = __TOOSMALL;
    else if ((ll == LLONG_MAX && errno == ERANGE) || ll > maxval)
      error = __TOOLARGE;
  }
  if (errstrp != NULL)
    *errstrp = ev[error].errstr;
  errno = ev[error].err;
  if (error)
    ll = 0;
  return (ll);
}

#define srandomdev(...) /* XXX stub for games/phantasia/setup */

static inline __always_inline uint32_t  /* XXX for games/fortune/strfile.nx */
arc4random_uniform(u_int32_t upper_bound)
{
  uint32_t r, min;
  if (upper_bound < 2)
    return 0;
  min = -upper_bound % upper_bound;
  for (;;) {
    r = rand();   /* should be good enough */
    if (r >= min)
      break;
  }
  return (r % upper_bound);
}
#endif
#if defined(__OpenBSD__) || defined(__NetBSD__)
#undef HAVE_FILENO_UNLOCKED
#undef HAVE_FEOF_UNLOCKED
#undef HAVE_FERROR_UNLOCKED
#undef fileno
#undef feof
#undef ferror
#endif
#ifdef __NetBSD__
#define srandomdev(...) /* XXX stub for games/phantasia/setup */
long long strtonum(const char *, long long, long long, const char **);
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/stdlib.h
#ifndef __compat_stdlib_h__
#define __compat_stdlib_h__
#if defined(__linux__) && defined(pacify_glibc_headers_GCC)
#include <features.h>
#endif
#if defined(__GLIBC__) && defined(pacify_glibc_headers_GCC)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wcast-qual"
#endif
#include_next <stdlib.h>
#if defined(__GLIBC__) && defined(pacify_glibc_headers_GCC)
#pragma GCC diagnostic pop
#endif
#if !defined(__DragonFly__) && !defined(__FreeBSD__) && !defined(__linux__)
#include <langinfo.h>
#include <regex.h>
static inline __always_inline int
rpmatch(const char *response)
{
  regex_t yes, no;
  int ret;
  if (regcomp(&yes, nl_langinfo(YESEXPR), REG_EXTENDED|REG_NOSUB) != 0)
     return (-1);
  if (regcomp(&no, nl_langinfo(NOEXPR), REG_EXTENDED|REG_NOSUB) != 0) {
     regfree(&yes);
     return (-1);
  }
  if (regexec(&yes, response, 0, NULL, 0) == 0)
    ret = 1;
  else if (regexec(&no, response, 0, NULL, 0) == 0)
    ret = 0;
  else
    ret = -1;
  regfree(&yes);
  regfree(&no);
  return (ret);
}
#endif
#ifdef __linux__
#include <inlined/stdlib.hi> /* arc4random, getprogname, mergesort etc */
#endif
#ifdef __NetBSD__  /* XXX only if _OPENBSD_SOURCE */
void   *reallocarray(void *, size_t, size_t);
long long strtonum(const char *, long long, long long, const char **);
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/err.h
#ifndef __compat_err_h__
#define __compat_err_h__
#include_next <err.h>
#ifdef __linux__
#include <inlined/err.hi> /* errc verrc etc */
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/signal.h
#ifndef __compat_signal_h__
#define __compat_signal_h__
#include_next <signal.h>
#ifdef __linux__
#define sys_signame sys_siglist
#define sys_nsig _NSIG
#endif
#if defined(__OpenBSD__) || defined(__NetBSD__)
#define sys_nsig _NSIG
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/db.h
#ifndef __compat_db_h__
#define __compat_db_h__
#ifndef __linux__
#include_next <signal.h>
#endif
#ifndef __linux__
#include_next <db.h>
#endif
#ifdef __linux__
#include <inlined/db.hi> /* cgetdb opendb etc */
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/grp.h
#ifndef __compat_grp_h__
#define __compat_grp_h__
#ifdef BOOTSTRAPPING
#define group_from_gid group_from_gid__z
#define gid_from_group gid_from_group__z
#endif
#include_next <grp.h>
#if defined(BOOTSTRAPPING) || defined(__linux__)
#include <sys/types.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifndef UNMLEN
#define UNMLEN 32
#endif
#undef group_from_gid
#undef gid_from_group
static inline __always_inline const char *
group_from_gid(gid_t gid, int noname)
{
  void *ptr;
  if (noname)
    return (NULL);
  ptr = malloc(UNMLEN);
  snprintf(ptr, UNMLEN, "%lu", (long) gid);
  return ptr;
}

static inline __always_inline int
gid_from_group(const char *name, gid_t *gid)
{
  if (name == NULL || gid == NULL)
    return -1;
  if (strcmp(name, "wheel") == 0) {
    *gid = 0;
    return 0;
  } else if (strcmp(name, "daemon") == 0) { /* for installworld */
    *gid = 1;
    return 0;
  } else if (strcmp(name, "operator") == 0) {
    *gid = 5;
    return 0;
  } else if (strcmp(name, "mail") == 0) {
    *gid = 6;
    return 0;
  } else if (strcmp(name, "games") == 0) {
    *gid = 13;
    return 0;
  } else if (strcmp(name, "uucp") == 0) {
    *gid = 66;
    return 0;
  } else if (strcmp(name, "dialer") == 0) {
    *gid = 68;
    return 0;
  } else if (strcmp(name, "network") == 0) {
    *gid = 69;
    return 0;
  }
  return -1;
}
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/pwd.h
#ifndef __compat_pwd_h__
#define __compat_pwd_h__
/* XXX for pwd_mkdb(1) */
#ifdef PWD_MKDB_CROSS
#define _PWF(x)         (1 << x)
#define _PWF_NAME       _PWF(0)
#define _PWF_PASSWD     _PWF(1)
#define _PWF_UID        _PWF(2)
#define _PWF_GID        _PWF(3)
#define _PWF_CHANGE     _PWF(4)
#define _PWF_CLASS      _PWF(5)
#define _PWF_GECOS      _PWF(6)
#define _PWF_DIR        _PWF(7)
#define _PWF_SHELL      _PWF(8)
#define _PWF_EXPIRE     _PWF(9)

#define passwd dfly_passwd

struct dfly_passwd {
  char    *pw_name;
  char    *pw_passwd;
  uid_t   pw_uid;
  gid_t   pw_gid;
  time_t  pw_change;
  char    *pw_class;
  char    *pw_gecos;
  char    *pw_dir;
  char    *pw_shell;
  time_t  pw_expire;
  int     pw_fields;
};

#define _PW_VERSIONED(x, v)     ((unsigned char)(((x) & 0xCF) | ((v)<<4)))
#define _PW_KEYBYNAME           '\x31'
#define _PW_KEYBYNUM            '\x32'
#define _PW_KEYBYUID            '\x33'
#define _PW_KEYYPENABLED        '\x34'
#define _PW_KEYYPBYNUM          '\x35'
#define _PWD_VERSION_KEY        "\xFF" "VERSION"
#define _PWD_CURRENT_VERSION    '\x04'

#define _PATH_PWD               "/etc"
#define _PASSWD                 "passwd"
#define _MASTERPASSWD           "master.passwd"
#define _PATH_MP_DB             "/etc/pwd.db"
#define _MP_DB                  "pwd.db"
#define _PATH_SMP_DB            "/etc/spwd.db"
#define _SMP_DB                 "spwd.db"
#else

#ifdef BOOTSTRAPPING
#define user_from_uid user_from_uid__z
#define uid_from_user uid_from_user__z
#endif
#include_next <pwd.h>
#if defined(BOOTSTRAPPING) || defined(__linux__)
#include <sys/types.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#undef user_from_uid
#undef uid_from_user
#ifndef UNMLEN
#define UNMLEN 32
#endif
static inline __always_inline const char *
user_from_uid(uid_t uid, int noname)
{
  void *ptr;
  if (noname)
    return (NULL);
  ptr = malloc(UNMLEN);
  snprintf(ptr, UNMLEN, "%lu", (long) uid);
  return ptr;
}

static inline __always_inline int
uid_from_user(const char *name, uid_t *uid)
{
  if (name == NULL || uid == NULL)
    return -1;
  if (strcmp(name, "root") == 0) {
    *uid = 0;
    return 0;
  } else if (strcmp(name, "daemon") == 0) { /* for installworld */
    *uid = 1;
    return 0;
  } else if (strcmp(name, "operator") == 0) {
    *uid = 2;
    return 0;
  } else if (strcmp(name, "mail") == 0) {
    *uid = 6;
    return 0;
  } else if (strcmp(name, "games") == 0) {
    *uid = 7;
    return 0;
  } else if (strcmp(name, "uucp") == 0) {
    *uid = 7;
    return 0;
  }
  return -1;
}
#endif
#ifdef __linux__
#include <sys/cdefs.h>
#include <limits.h> /* GID_MAX UID_MAX needed for mtree */
#include <stdint.h>

#ifndef GID_MAX
#define GID_MAX UINT_MAX
#endif
#ifndef UID_MAX
#define UID_MAX UINT_MAX
#endif

#endif
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/vis.h
#ifndef __compat_vis_h__
#define __compat_vis_h__
#include <vis_portable.h>  /* vis unvis replacement, yes IBCN */
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/string.h
#ifndef __compat_string_h__
#define __compat_string_h__
#include <sys/cdefs.h>
#ifdef __linux__  /* fix liberty.h */
/* no basename() unhook, issue in patch(1) */
#ifdef __OPTIMIZE__
#undef __OPTIMIZE__    /* deal with strchr() and rindex() optimizations */
#define ____OPTIMIZE__
#endif
#endif
#include_next <string.h>
#ifdef __linux__
#ifdef ____OPTIMIZE__
#define __OPTIMIZE__ 1
#endif
#endif
#ifdef __linux__
#include <inlined/string.hi> /* strlcat strlcpy strmode */
#endif
#if defined(__OpenBSD__) || defined(__NetBSD__)
static inline __always_inline void *
mempcpy(void *dest, const void *src, size_t len)
{
  return ((char *)memcpy(dest, src, len) + len);
}
#define MBUITER_INLINE inline __always_inline
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/simple/string.h
#ifndef __compat_string_h__
#define __compat_string_h__
#include <sys/cdefs.h>
#ifdef __linux__  /* fix liberty.h */
#undef basename
#define basename __basename
#ifdef __OPTIMIZE__
#undef __OPTIMIZE__    /* deal with strchr() and rindex() optimizations */
#define ____OPTIMIZE__
#endif
#endif
#include_next <string.h>
#ifdef __linux__
#ifdef ____OPTIMIZE__
#define __OPTIMIZE__ 1
#endif
#undef basename
#endif
#if defined(__OpenBSD__) || defined(__NetBSD__)
static inline __always_inline void *
mempcpy(void *dest, const void *src, size_t len)
{
  return ((char *)memcpy(dest, src, len) + len);
}
static inline __always_inline int
ffsll(long long mask)
{
 int bit;
 if (mask == 0)
   return (0);
 for (bit = 1; !(mask & 1); bit++)
   mask = (unsigned long long)mask >> 1;
 return (bit);
}
#define MBUITER_INLINE inline __always_inline
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/simple/libiberty.h
#ifndef __compat_libiberty_h__
#define __compat_libiberty_h__
#include_next "libiberty.h"
#ifdef __linux__
#ifdef __cplusplus
#define setproctitle(...)  /* so as not to bundle setproctitle.c */
#endif
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/unistd.h
#ifndef __compat_unistd_h__
#define __compat_unistd_h__
#include_next <unistd.h>
#ifndef OFF_MAX
#define OFF_MAX LONG_MAX
#endif
#ifndef __DragonFly__
#define varsym_get(x,y,z,v) (-1)
#endif
#if defined(__OpenBSD__) || defined(__NetBSD__)
#define eaccess access
#endif
#ifdef __NetBSD__  /* XXX bin/mv/mv.c statfs() */
#undef MNAMELEN
#endif
#ifdef __linux__
#include <inlined/unistd.hi> /* bsd_getopt getmode setmode */
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/sys/event.h
#ifndef __compat_sys_event_h__
#define __compat_sys_event_h__
#if defined(__DragonFly__) || defined(__FreeBSD__)
#include_next <sys/event.h>
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/sys/ucred.h
#ifndef __compat_sys_ucred_h__
#define __compat_sys_ucred_h__
#ifndef __linux__
#include_next <sys/ucred.h>
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/sys/tree.h
#ifndef __compat_sys_tree_h__
#define __compat_sys_tree_h__
#ifndef __linux__
#include_next <sys/tree.h>
#endif
#ifdef __linux__
#include <inlined/tree.hi> /* RB_ stuff */
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/sys/consio.h
#ifndef __compat_sys_consio_h__
#define __compat_sys_consio_h__
#if 0
#include_next <sys/consio.h>
#endif
#if 1
struct _scrmap {
  char            scrmap[256];
};
typedef struct _scrmap  scrmap_t; /* XXX share/syscons/mapsmk/ */
#endif
#endif
EOF
cp /tmp/dfly/cross/compat/sys/consio.h /tmp/dfly/cross/simple/sys/consio.h

cat << 'EOF' > /tmp/dfly/cross/compat/sys/linker.h
#ifndef __compat_sys_linker_h__
#define __compat_sys_linker_h__
#ifndef __linux__
#include_next <sys/linker.h>
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/sys/module.h
#ifndef __compat_sys_module_h__
#define __compat_sys_module_h__
#ifndef __linux__
#include_next <sys/module.h>
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/sys/mount.h
#ifndef __compat_sys_mount_h__
#define __compat_sys_mount_h__
#ifdef __NetBSD__  /* XXX find(1) functions.c */
#define f_flag f_flags
#endif
#include_next <sys/mount.h>
#if !defined(__DragonFly__) && !defined(__FreeBSD__) && !defined(__NetBSD__)
#include <sys/cdefs.h>
#include <stddef.h>
#define MAXPHYS (4 * 1024)
#ifdef __linux__
#include <sys/statfs.h>
#define f_iosize f_bsize
#endif
#endif
#ifdef __NetBSD__
#include <sys/statvfs.h>  /* XXX bin/rm/rm.c fstatfs() */
#define statfs statvfs
#define fstatfs fstatvfs
#undef f_flag  /* XXX find(1) */
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/sys/stat.h
#ifndef __compat_sys_stat_h__
#define __compat_sys_stat_h__
#include_next <sys/stat.h>
#if !defined(__DragonFly__) && !defined(__FreeBSD__)
#define lchmod chmod
#endif
#ifndef S_ISWHT
#define S_ISWHT(x) 0
#endif
#ifdef __linux__
#define MNT_RDONLY MS_RDONLY
#define MNT_LOCAL -2 /* dummy for find(1) */
#ifndef MAXLOGNAME   /* for find(1) */
#define MAXLOGNAME 33
#endif
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/sys/time.h
#ifndef __compat_sys_time_h__
#define __compat_sys_time_h__
#include_next <sys/time.h>
#if !defined(__DragonFly__) && !defined(__FreeBSD__)
#define lutimes utimes
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/sys/mtio.h
#ifndef __compat_sys_mtio_h__
#define __compat_sys_mtio_h__
#include_next <sys/mtio.h>
#if defined(__OpenBSD__) || defined(__NetBSD__)
#include <sys/ioctl.h>
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/sys/queue.h
#ifndef __compat_sys_queue_h__
#define __compat_sys_queue_h__
#include_next <sys/queue.h>
#if defined(__OpenBSD__)
#define STAILQ_HEAD(name, type) struct name { \
  struct type *stqh_first; \
  struct type **stqh_last; \
}
#define STAILQ_HEAD_INITIALIZER(head) { NULL, &(head).stqh_first }
#define STAILQ_ENTRY(type)  struct { struct type *stqe_next;  }
#define STAILQ_INIT(head) do { \
  (head)->stqh_first = NULL; \
  (head)->stqh_last = &(head)->stqh_first; \
} while (/*CONSTCOND*/0)
#define STAILQ_INSERT_HEAD(head, elm, field) do { \
  if (((elm)->field.stqe_next = (head)->stqh_first) == NULL) \
    (head)->stqh_last = &(elm)->field.stqe_next; \
  (head)->stqh_first = (elm); \
} while (/*CONSTCOND*/0)
#define STAILQ_INSERT_TAIL(head, elm, field) do { \
  (elm)->field.stqe_next = NULL; \
  *(head)->stqh_last = (elm); \
  (head)->stqh_last = &(elm)->field.stqe_next; \
} while (/*CONSTCOND*/0)
#define STAILQ_INSERT_AFTER(head, listelm, elm, field) do {\
  if (((elm)->field.stqe_next = (listelm)->field.stqe_next) == NULL) \
    (head)->stqh_last = &(elm)->field.stqe_next; \
  (listelm)->field.stqe_next = (elm); \
} while (/*CONSTCOND*/0)
#define STAILQ_REMOVE_HEAD(head, field) do { \
  if (((head)->stqh_first = (head)->stqh_first->field.stqe_next) == NULL) \
    (head)->stqh_last = &(head)->stqh_first;\
} while (/*CONSTCOND*/0)
#define STAILQ_REMOVE(head, elm, type, field) do { \
  if ((head)->stqh_first == (elm)) { \
      STAILQ_REMOVE_HEAD((head), field); \
  } else { \
    struct type *curelm = (head)->stqh_first; \
    while (curelm->field.stqe_next != (elm)) \
      curelm = curelm->field.stqe_next; \
    if ((curelm->field.stqe_next = \
         curelm->field.stqe_next->field.stqe_next) == NULL) \
      (head)->stqh_last = &(curelm)->field.stqe_next; \
  } \
} while (/*CONSTCOND*/0)
#define STAILQ_FOREACH(var, head, field) \
  for ((var) = ((head)->stqh_first); \
    (var); \
  (var) = ((var)->field.stqe_next))
#define STAILQ_CONCAT(head1, head2) do { \
 if (!STAILQ_EMPTY((head2))) { \
   *(head1)->stqh_last = (head2)->stqh_first; \
    (head1)->stqh_last = (head2)->stqh_last; \
   STAILQ_INIT((head2)); \
 } \
} while (/*CONSTCOND*/0)
#define STAILQ_EMPTY(head)      ((head)->stqh_first == NULL)
#define STAILQ_FIRST(head)      ((head)->stqh_first)
#define STAILQ_NEXT(elm, field) ((elm)->field.stqe_next)
#endif
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/inlined/db.hi
#ifdef __linux__
#include <sys/cdefs.h>
#include <sys/param.h>
#include <sys/types.h>
#include <sys/fcntl.h>
#include <endian.h>
#include <errno.h>
#include <limits.h>
#include <stddef.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

#ifndef O_EXLOCK
#define O_EXLOCK 0
#endif
#ifndef O_SHLOCK
#define O_SHLOCK 0
#endif

#define RET_ERROR       -1

#define R_CURSOR        1
#define R_FIRST         3
#define R_NEXT          7
#define R_NOOVERWRITE   8

typedef struct {
  void    *data;
  size_t   size;
} DBT;
typedef enum { DB_BTREEz, DB_HASH, DB_RECNOz } DBTYPE;
#if UINT_MAX > 65535
#define DB_LOCK         0x20000000
#define DB_SHMEM        0x40000000
#define DB_TXN          0x80000000
#else
#define DB_LOCK             0x2000
#define DB_SHMEM            0x4000
#define DB_TXN              0x8000
#endif
typedef struct __db {
  DBTYPE type;
  int (*close)(struct __db *);
  int (*del)(const struct __db *, const DBT *, unsigned int);
  int (*get)(const struct __db *, const DBT *, DBT *, unsigned int);
  int (*put)(const struct __db *, DBT *, const DBT *, unsigned int);
  int (*seq)(const struct __db *, DBT *, DBT *, unsigned int);
  int (*sync)(const struct __db *, unsigned int);
  void *internal;
  int (*fd)(const struct __db *);
} DB;

#define HASHMAGIC       0x061561
#define HASHVERSION     2
typedef struct {
        unsigned int    bsize;
        unsigned int    ffactor;
        unsigned int    nelem;
        unsigned int    cachesize;
        uint32_t (*hash)(const void *, size_t);
        int     lorder;
} HASHINFO;

typedef enum {
  HASH_GET, HASH_PUT, HASH_PUTNEW, HASH_DELETE, HASH_FIRST, HASH_NEXT
} ACTION;

typedef struct _bufhead BUFHEAD;

#define DB_RETURN_ERROR(ERR, LOC)  { save_errno = ERR; goto LOC; }
#define DB_SUCCESS  (0)
#define DB_ERROR   (-1)
#define DB_ABNORMAL (1)

struct _bufhead {
  BUFHEAD         *prev;
  BUFHEAD         *next;
  BUFHEAD         *ovfl;
  uint32_t         addr;
  char            *page;
  char            flags;
#define BUF_MOD         0x0001
#define BUF_DISK        0x0002
#define BUF_BUCKET      0x0004
#define BUF_PIN         0x0008
};

typedef BUFHEAD **SEGMENT;
typedef struct hashhdr {
  int32_t         magic;
  int32_t         version;
  uint32_t        lorder;
  int32_t         bsize;
  int32_t         bshift;
  int32_t         dsize;
  int32_t         ssize;
  int32_t         sshift;
  int32_t         ovfl_point;
  int32_t         last_freed;
  uint32_t        max_bucket;
  uint32_t        high_mask;
  uint32_t        low_mask;
  uint32_t        ffactor;
  int32_t         nkeys;
  int32_t         hdrpages;
  int32_t         h_charkey;
#define NCACHED 32
  int32_t         spares[NCACHED];
  uint16_t        bitmaps[NCACHED];
} HASHHDR;

typedef struct htab {
  HASHHDR         hdr;
  int             nsegs;
  int             exsegs;
  uint32_t       (*hash)(const void *, size_t);
  int             flags;
  int             fp;
  char            *tmp_buf;
  char            *tmp_key;
  BUFHEAD         *cpage;
  int             cbucket;
  int             cndx;
  int             error;
  int             new_file;
  int             save_file;
  uint32_t        *mapp[NCACHED];
  int             nmaps;
  int             nbufs;
  BUFHEAD         bufhead;
  SEGMENT         *dir;
} HTAB;

#define DB_NOM_BSIZE            16384
#define DB_MAX_BSIZE            32768
#define DB_MIN_BUFFERS          6
#define DB_MINHDRSIZE           512
#define DB_DEF_BUFSIZE          65536
#define DB_BYTE_SHIFT           3
#define DB_DEF_BUCKET_SIZE      4096
#define DB_DEF_BUCKET_SHIFT     12
#define DB_DEF_SEGSIZE          256
#define DB_DEF_SEGSIZE_SHIFT    8
#define DB_DEF_DIRSIZE          256
#define DB_DEF_FFACTOR          65536
#define DB_MIN_FFACTOR          4
#define DB_CHARKEY              "%$sniglet^&"
#define DB_INT_BYTE_SHIFT       5
#define DB_ALL_SET              ((uint32_t)0xFFFFFFFF)

#define DB_SPLITSHIFT   11
#define DB_SPLITMASK    0x7FF
#define DB_SPLITNUM(N)  (((uint32_t)(N)) >> DB_SPLITSHIFT)
#define DB_OPAGENUM(N)  ((N) & DB_SPLITMASK)
#define DB_OADDR_OF(S,O)   ((uint32_t)((uint32_t)(S) << DB_SPLITSHIFT) + (O))
#define DB_BUCKET_TO_PAGE(B) (B) + hashp->hdr.hdrpages + \
        ((B) ? hashp->hdr.spares[__dblog2((B)+1)-1] : 0)
#define DB_OADDR_TO_PAGE(B) \
        DB_BUCKET_TO_PAGE ( (1 << DB_SPLITNUM((B))) -1 ) + DB_OPAGENUM((B));

#define DB_BITS_PER_MAP 32
#define DB_CLRBIT(A, N) ((A)[(N)/DB_BITS_PER_MAP] &= ~(1<<((N)%DB_BITS_PER_MAP)))
#define DB_SETBIT(A, N) ((A)[(N)/DB_BITS_PER_MAP] |= (1<<((N)%DB_BITS_PER_MAP)))
#define DB_ISSET(A, N)  ((A)[(N)/DB_BITS_PER_MAP] & (1<<((N)%DB_BITS_PER_MAP)))

#define DB_M_32_SWAP(a) { uint32_t _tmp = a; \
  ((char *)&a)[0] = ((char *)&_tmp)[3]; ((char *)&a)[1] = ((char *)&_tmp)[2]; \
  ((char *)&a)[2] = ((char *)&_tmp)[1]; ((char *)&a)[3] = ((char *)&_tmp)[0]; }
#define DB_P_32_COPY(a, b) { \
  ((char *)&(b))[0] = ((char *)&(a))[3]; ((char *)&(b))[1] = ((char *)&(a))[2];\
  ((char *)&(b))[2] = ((char *)&(a))[1]; ((char *)&(b))[3] = ((char *)&(a))[0];}

#define DB_M_16_SWAP(a) { uint16_t _tmp = a; \
  ((char *)&a)[0] = ((char *)&_tmp)[1]; ((char *)&a)[1] = ((char *)&_tmp)[0]; }
#define DB_P_16_COPY(a, b) { \
  ((char *)&(b))[0] = ((char *)&(a))[1]; ((char *)&(b))[1] = ((char *)&(a))[0];}

static uint32_t
db_hash4(const void *key, size_t len)
{
  uint32_t h, loop;
  const uint8_t *k;
#define HASH4   h = (h << 5) + h + *k++;
  h = 0;
  k = key;
  if (len > 0) {
    loop = (len + 8 - 1) >> 3;
    switch (len & (8 - 1)) {
    case 0:
      do {
        HASH4;
        /* FALLTHROUGH */
    case 7:
        HASH4;
        /* FALLTHROUGH */
    case 6:
        HASH4;
        /* FALLTHROUGH */
    case 5:
        HASH4;
        /* FALLTHROUGH */
    case 4:
        HASH4;
        /* FALLTHROUGH */
  case 3:
        HASH4;
        /* FALLTHROUGH */
  case 2:
        HASH4;
        /* FALLTHROUGH */
  case 1:
        HASH4;
      } while (--loop);
    }
  }
  return (h);
#undef HASH4
}

uint32_t (*__default_hash)(const void *, size_t) = db_hash4;

static inline __always_inline uint32_t
__dblog2(uint32_t num)
{
  uint32_t i, limit;
  limit = 1;
  for (i = 0; limit < num; limit = limit << 1, i++);
  return (i);
}

static inline __always_inline void
__buf_init(HTAB *hashp, int nbytes)
{
  BUFHEAD *bfp;
  int npages;
  bfp = &(hashp->bufhead);
  npages = (nbytes + hashp->hdr.bsize - 1) >> hashp->hdr.bshift;
  npages = MAX(npages, DB_MIN_BUFFERS);
  hashp->nbufs = npages;
  bfp->next = bfp;
  bfp->prev = bfp;
}

static inline __always_inline int
open_temp(HTAB *hashp)
{
  sigset_t set, oset;
  int len;
  char *envtmp = NULL;
  char path[MAXPATHLEN];
  envtmp = getenv("TMPDIR");
  len = snprintf(path,
  sizeof(path), "%s/_hash.XXXXXX", envtmp ? envtmp : "/tmp");
  if (len < 0 || len >= (int)sizeof(path)) {
    errno = ENAMETOOLONG;
    return (-1);
  }
  sigfillset(&set);
  sigprocmask(SIG_BLOCK, &set, &oset);
  if ((hashp->fp = mkostemp(path, O_CLOEXEC)) != -1) {
    unlink(path);
    fcntl(hashp->fp, F_SETFD, 1);
  }
  sigprocmask(SIG_SETMASK, &oset, NULL);
  return (hashp->fp != -1 ? 0 : -1);
}

#define DB_BUF_REMOVE(B) { \
        (B)->prev->next = (B)->next; \
        (B)->next->prev = (B)->prev; \
}
#define DB_BUF_INSERT(B, P) { \
        (B)->next = (P)->next; \
        (B)->prev = (P); \
        (P)->next = (B); \
        (B)->next->prev = (B); \
}
#define DB_MRU_INSERT(B) DB_BUF_INSERT((B), &hashp->bufhead)
#define DB_LRU_INSERT(B) DB_BUF_INSERT((B), hashp->bufhead.prev)

#define DB_ISDISK(X) ((uint32_t)(ptrdiff_t)(X)&0x2)
#define DB_PAGE_INIT(P) { \
        ((uint16_t *)(P))[0] = 0; \
        ((uint16_t *)(P))[1] = hashp->hdr.bsize - 3 * sizeof(uint16_t); \
        ((uint16_t *)(P))[2] = hashp->hdr.bsize; }

static inline __always_inline int
__get_page(HTAB *hashp, char *p, uint32_t bucket, int is_bucket, int is_disk,
    int is_bitmap)
{
  int fd, page, size, rsize;
  uint16_t *bp;
  fd = hashp->fp;
  size = hashp->hdr.bsize;
  if ((fd == -1) || !is_disk) {
    DB_PAGE_INIT(p);
    return (0);
  }
  if (is_bucket)
    page = DB_BUCKET_TO_PAGE(bucket);
  else
    page = DB_OADDR_TO_PAGE(bucket);
  if ((rsize = pread(fd, p, size, (off_t)page << hashp->hdr.sshift)) == -1)
    return (-1);
  bp = (uint16_t *)p;
  if (!rsize)
    bp[0] = 0;
  else
    if (rsize != size) {
      errno = EFTYPE;
      return (-1);
    }
  if (!is_bitmap && !bp[0]) {
    DB_PAGE_INIT(p);
  } else
    if (hashp->hdr.lorder != __BYTE_ORDER) {
      int i, max;
      if (is_bitmap) {
        max = hashp->hdr.bsize >> 2;
        for (i = 0; i < max; i++)
          DB_M_32_SWAP(((int *)p)[i]);
      } else {
        DB_M_16_SWAP(bp[0]);
        max = bp[0] + 2;
        for (i = 1; i <= max; i++)
          DB_M_16_SWAP(bp[i]);
      }
    }
  return (0);
}

static inline __always_inline int
__put_page(HTAB *hashp, char *p, uint32_t bucket, int is_bucket, int is_bitmap)
{
  int fd, page, size, wsize;
  size = hashp->hdr.bsize;
  if ((hashp->fp == -1) && open_temp(hashp))
    return (-1);
  fd = hashp->fp;
  if (hashp->hdr.lorder != __BYTE_ORDER) {
    int i, max;
    if (is_bitmap) {
      max = hashp->hdr.bsize >> 2;
      for (i = 0; i < max; i++)
        DB_M_32_SWAP(((int *)p)[i]);
    } else {
      max = ((uint16_t *)p)[0] + 2;
      for (i = 0; i <= max; i++)
        DB_M_16_SWAP(((uint16_t *)p)[i]);
    }
  }
  if (is_bucket)
    page = DB_BUCKET_TO_PAGE(bucket);
  else
    page = DB_OADDR_TO_PAGE(bucket);
  if ((wsize = pwrite(fd, p, size, (off_t)page << hashp->hdr.bshift)) == -1)
    return (-1);
  if (wsize != size) {
    errno = EFTYPE;
    return (-1);
  }
  return (0);
}

static inline __always_inline BUFHEAD *
newbuf(HTAB *hashp, uint32_t addr, BUFHEAD *prev_bp)
{
  BUFHEAD *bp;
  BUFHEAD *xbp;
  BUFHEAD *next_xbp;
  SEGMENT segp;
  int segment_ndx;
  uint16_t oaddr, *shortp;
  oaddr = 0;
  bp = hashp->bufhead.prev;
  if (bp == hashp->cpage) {
    DB_BUF_REMOVE(bp);
    DB_MRU_INSERT(bp);
    bp = hashp->bufhead.prev;
  }
  if (hashp->nbufs == 0 && prev_bp && bp->ovfl) {
    BUFHEAD *ovfl;
    for (ovfl = bp->ovfl; ovfl ; ovfl = ovfl->ovfl) {
      if (ovfl == prev_bp) {
        hashp->nbufs++;
        break;
      }
    }
  }
  if (hashp->nbufs || (bp->flags & BUF_PIN) || bp == hashp->cpage) {
    if ((bp = (BUFHEAD *)calloc(1, sizeof(BUFHEAD))) == NULL)
      return (NULL);
    if ((bp->page = (char *)calloc(1, hashp->hdr.bsize)) == NULL) {
      free(bp);
      return (NULL);
    }
    if (hashp->nbufs)
      hashp->nbufs--;
  } else {
    DB_BUF_REMOVE(bp);
    if ((bp->addr != 0) || (bp->flags & BUF_BUCKET)) {
      shortp = (uint16_t *)bp->page;
      if (shortp[0])
        oaddr = shortp[shortp[0] - 1];
      if ((bp->flags & BUF_MOD) && __put_page(hashp, bp->page,
          bp->addr, (int)(bp->flags & BUF_BUCKET), 0))
        return (NULL);
      if ((bp->flags & BUF_BUCKET)) {
        segment_ndx = bp->addr & (hashp->hdr.ssize - 1);
        segp = hashp->dir[bp->addr >> hashp->hdr.sshift];
        if (hashp->new_file &&
            ((bp->flags & BUF_MOD) || DB_ISDISK(segp[segment_ndx])))
          segp[segment_ndx] = (BUFHEAD *)BUF_DISK;
        else
          segp[segment_ndx] = NULL;
      }
      for (xbp = bp; xbp->ovfl;) {
        next_xbp = xbp->ovfl;
        xbp->ovfl = 0;
        xbp = next_xbp;
        if ((xbp->flags & BUF_BUCKET) || (oaddr != xbp->addr))
          break;
        shortp = (uint16_t *)xbp->page;
        if (shortp[0])
          oaddr = shortp[shortp[0] - 1];
        if ((xbp->flags & BUF_MOD) && __put_page(hashp, xbp->page, xbp->addr, 0, 0))
          return (NULL);
        xbp->addr = 0;
        xbp->flags = 0;
        DB_BUF_REMOVE(xbp);
        DB_LRU_INSERT(xbp);
      }
    }
  }
  bp->addr = addr;
  bp->ovfl = NULL;
  if (prev_bp) {
    prev_bp->ovfl = bp;
    bp->flags = 0;
  } else
    bp->flags = BUF_BUCKET;
  DB_MRU_INSERT(bp);
  return (bp);
}

static inline __always_inline BUFHEAD *
__get_buf(HTAB *hashp, uint32_t addr, BUFHEAD *prev_bp, int newpage)
{
  BUFHEAD *bp;
  uint32_t is_disk_mask;
  int is_disk, segment_ndx __pacify(= 0);
  SEGMENT segp __pacify(= NULL);
  is_disk = 0;
  is_disk_mask = 0;
  if (prev_bp) {
    bp = prev_bp->ovfl;
    if (!bp || (bp->addr != addr))
       bp = NULL;
    if (!newpage)
      is_disk = BUF_DISK;
  } else {
    segment_ndx = addr & (hashp->hdr.ssize - 1);
    segp = hashp->dir[addr >> hashp->hdr.sshift];
    bp = ((BUFHEAD *)((ptrdiff_t)(segp[segment_ndx])&~0x3));
    is_disk_mask = DB_ISDISK(segp[segment_ndx]);
    is_disk = is_disk_mask || !hashp->new_file;
  }
  if (!bp) {
    bp = newbuf(hashp, addr, prev_bp);
    if (!bp || __get_page(hashp, bp->page, addr, !prev_bp, is_disk, 0))
      return (NULL);
    if (!prev_bp)
      segp[segment_ndx] = (BUFHEAD *)((ptrdiff_t)bp | is_disk_mask);
  } else {
    DB_BUF_REMOVE(bp);
    DB_MRU_INSERT(bp);
  }
  return (bp);
}

#if __BYTE_ORDER == __LITTLE_ENDIAN
static inline __always_inline void
swap_header_copy(HASHHDR *srcp, HASHHDR *destp)
{
  int i;
  DB_P_32_COPY(srcp->magic, destp->magic);
  DB_P_32_COPY(srcp->version, destp->version);
  DB_P_32_COPY(srcp->lorder, destp->lorder);
  DB_P_32_COPY(srcp->bsize, destp->bsize);
  DB_P_32_COPY(srcp->bshift, destp->bshift);
  DB_P_32_COPY(srcp->dsize, destp->dsize);
  DB_P_32_COPY(srcp->ssize, destp->ssize);
  DB_P_32_COPY(srcp->sshift, destp->sshift);
  DB_P_32_COPY(srcp->ovfl_point, destp->ovfl_point);
  DB_P_32_COPY(srcp->last_freed, destp->last_freed);
  DB_P_32_COPY(srcp->max_bucket, destp->max_bucket);
  DB_P_32_COPY(srcp->high_mask, destp->high_mask);
  DB_P_32_COPY(srcp->low_mask, destp->low_mask);
  DB_P_32_COPY(srcp->ffactor, destp->ffactor);
  DB_P_32_COPY(srcp->nkeys, destp->nkeys);
  DB_P_32_COPY(srcp->hdrpages, destp->hdrpages);
  DB_P_32_COPY(srcp->h_charkey, destp->h_charkey);
  for (i = 0; i < NCACHED; i++) {
    DB_P_32_COPY(srcp->spares[i], destp->spares[i]);
    DB_P_16_COPY(srcp->bitmaps[i], destp->bitmaps[i]);
  }
}

static inline __always_inline void
swap_header(HTAB *hashp)
{
  HASHHDR *hdrp;
  int i;
  hdrp = &hashp->hdr;
  DB_M_32_SWAP(hdrp->magic);
  DB_M_32_SWAP(hdrp->version);
  DB_M_32_SWAP(hdrp->lorder);
  DB_M_32_SWAP(hdrp->bsize);
  DB_M_32_SWAP(hdrp->bshift);
  DB_M_32_SWAP(hdrp->dsize);
  DB_M_32_SWAP(hdrp->ssize);
  DB_M_32_SWAP(hdrp->sshift);
  DB_M_32_SWAP(hdrp->ovfl_point);
  DB_M_32_SWAP(hdrp->last_freed);
  DB_M_32_SWAP(hdrp->max_bucket);
  DB_M_32_SWAP(hdrp->high_mask);
  DB_M_32_SWAP(hdrp->low_mask);
  DB_M_32_SWAP(hdrp->ffactor);
  DB_M_32_SWAP(hdrp->nkeys);
  DB_M_32_SWAP(hdrp->hdrpages);
  DB_M_32_SWAP(hdrp->h_charkey);
  for (i = 0; i < NCACHED; i++) {
    DB_M_32_SWAP(hdrp->spares[i]);
    DB_M_16_SWAP(hdrp->bitmaps[i]);
  }
}
#endif

static inline __always_inline int
flush_meta(HTAB *hashp)
{
  HASHHDR *whdrp;
#if __BYTE_ORDER == __LITTLE_ENDIAN
  HASHHDR whdr;
#endif
  int fp, i, wsize;
  if (!hashp->save_file)
    return (0);
  hashp->hdr.magic = HASHMAGIC;
  hashp->hdr.version = HASHVERSION;
  hashp->hdr.h_charkey = hashp->hash(DB_CHARKEY, sizeof(DB_CHARKEY));
  fp = hashp->fp;
  whdrp = &hashp->hdr;
#if __BYTE_ORDER == __LITTLE_ENDIAN
  whdrp = &whdr;
  swap_header_copy(&hashp->hdr, whdrp);
#endif
  if ((wsize = pwrite(fp, whdrp, sizeof(HASHHDR), (off_t)0)) == -1)
    return (-1);
  else
    if (wsize != sizeof(HASHHDR)) {
      errno = EFTYPE;
      hashp->error = errno;
      return (-1);
    }
  for (i = 0; i < NCACHED; i++)
    if (hashp->mapp[i])
      if (__put_page(hashp, (char *)hashp->mapp[i],
                     hashp->hdr.bitmaps[i], 0, 1))
        return (-1);
  return (0);
}

static int
collect_data(HTAB *hashp, BUFHEAD *bufp, int len, int set)
{
  uint16_t *bp;
  char *p;
  BUFHEAD *xbp;
  uint16_t save_addr;
  int mylen, totlen;
  p = bufp->page;
  bp = (uint16_t *)p;
  mylen = hashp->hdr.bsize - bp[1];
  save_addr = bufp->addr;
  if (bp[2] == 3 /*FULL_KEY_DATA*/) {
      totlen = len + mylen;
    if (hashp->tmp_buf)
      free(hashp->tmp_buf);
    if ((hashp->tmp_buf = (char *)malloc(totlen)) == NULL)
      return (-1);
    if (set) {
      hashp->cndx = 1;
      if (bp[0] == 2) {
        hashp->cpage = NULL;
        hashp->cbucket++;
      } else {
        hashp->cpage = __get_buf(hashp, bp[bp[0] - 1], bufp, 0);
        if (!hashp->cpage)
          return (-1);
        else if (!((uint16_t *)hashp->cpage->page)[0]) {
          hashp->cbucket++;
          hashp->cpage = NULL;
        }
      }
    }
  } else {
    xbp = __get_buf(hashp, bp[bp[0] - 1], bufp, 0);
    if (!xbp || ((totlen = collect_data(hashp, xbp, len + mylen, set)) < 1))
      return (-1);
  }
  if (bufp->addr != save_addr) {
    errno = EINVAL;
    return (-1);
  }
  memmove(&hashp->tmp_buf[len], (bufp->page) + bp[1], mylen);
  return (totlen);
}

#define DB_PAIRSIZE(K,D)   (2*sizeof(uint16_t) + (K)->size + (D)->size)
#define DB_BIGOVERHEAD     (4*sizeof(uint16_t))
#define DB_KEYSIZE(K)      (4*sizeof(uint16_t) + (K)->size);
#define DB_OVFLSIZE        (2*sizeof(uint16_t))
#define DB_FREESPACE(P)    ((P)[(P)[0]+1])
#define DB_OFFSET(P)       ((P)[(P)[0]+2])
#define DB_PAIRFITS(P,K,D) \
        (((P)[2] >= 4 /*REAL_KEY*/) && \
            (DB_PAIRSIZE((K),(D)) + DB_OVFLSIZE) <= DB_FREESPACE((P)))
#define DB_PAGE_META(N)    (((N)+3) * sizeof(uint16_t))

typedef struct {
  BUFHEAD *newp;
  BUFHEAD *oldp;
  BUFHEAD *nextp;
  uint16_t next_addr;
} SPLIT_RETURN;

static inline __always_inline int
__big_return(HTAB *hashp, BUFHEAD *bufp, int ndx, DBT *val, int set_current)
{
  BUFHEAD *save_p;
  uint16_t *bp, len, off, save_addr;
  char *tp;
  bp = (uint16_t *)bufp->page;
  while (bp[ndx + 1] == 1 /*PARTIAL_KEY*/) {
    bufp = __get_buf(hashp, bp[bp[0] - 1], bufp, 0);
    if (!bufp)
      return (-1);
    bp = (uint16_t *)bufp->page;
    ndx = 1;
  }
  if (bp[ndx + 1] == 2 /*FULL_KEY*/) {
    bufp = __get_buf(hashp, bp[bp[0] - 1], bufp, 0);
    if (!bufp)
      return (-1);
    bp = (uint16_t *)bufp->page;
    save_p = bufp;
    save_addr = save_p->addr;
    off = bp[1];
    len = 0;
  } else
    if (!DB_FREESPACE(bp)) {
      off = bp[bp[0]];
      len = bp[1] - off;
      save_p = bufp;
      save_addr = bufp->addr;
      bufp = __get_buf(hashp, bp[bp[0] - 1], bufp, 0);
      if (!bufp)
        return (-1);
      bp = (uint16_t *)bufp->page;
    } else {
      tp = (char *)bp;
      off = bp[bp[0]];
      val->data = (unsigned char *)tp + off;
      val->size = bp[1] - off;
      if (set_current) {
        if (bp[0] == 2) {
          hashp->cpage = NULL;
          hashp->cbucket++;
          hashp->cndx = 1;
        } else {
          hashp->cpage = __get_buf(hashp,
          bp[bp[0] - 1], bufp, 0);
          if (!hashp->cpage)
            return (-1);
          hashp->cndx = 1;
          if (!((uint16_t *)hashp->cpage->page)[0]) {
            hashp->cbucket++;
            hashp->cpage = NULL;
          }
        }
      }
      return (0);
    }
  val->size = (size_t)collect_data(hashp, bufp, (int)len, set_current);
  if (val->size == (size_t)-1)
    return (-1);
  if (save_p->addr != save_addr) {
    errno = EINVAL;
    return (-1);
  }
  memmove(hashp->tmp_buf, (save_p->page) + off, len);
  val->data = (unsigned char *)hashp->tmp_buf;
  return (0);
}

static int
collect_key(HTAB *hashp, BUFHEAD *bufp, int len, DBT *val, int set)
{
  BUFHEAD *xbp;
  char *p;
  int mylen, totlen;
  uint16_t *bp, save_addr;
  p = bufp->page;
  bp = (uint16_t *)p;
  mylen = hashp->hdr.bsize - bp[1];
  save_addr = bufp->addr;
  totlen = len + mylen;
  if (bp[2] == 2 /*FULL_KEY*/ || bp[2] == 3 /*FULL_KEY_DATA*/) {
    if (hashp->tmp_key != NULL)
      free(hashp->tmp_key);
    if ((hashp->tmp_key = (char *)malloc(totlen)) == NULL)
      return (-1);
    if (__big_return(hashp, bufp, 1, val, set))
      return (-1);
  } else {
    xbp = __get_buf(hashp, bp[bp[0] - 1], bufp, 0);
    if (!xbp || ((totlen = collect_key(hashp, xbp, totlen, val, set)) < 1))
      return (-1);
  }
  if (bufp->addr != save_addr) {
    errno = EINVAL;
    return (-1);
  }
  memmove(&hashp->tmp_key[len], (bufp->page) + bp[1], mylen);
  return (totlen);
}

static inline __always_inline int
__big_keydata(HTAB *hashp, BUFHEAD *bufp, DBT *key, DBT *val, int set)
{
  key->size = (size_t)collect_key(hashp, bufp, 0, val, set);
  if (key->size == (size_t)-1)
    return (-1);
  key->data = (unsigned char *)hashp->tmp_key;
  return (0);
}

static inline __always_inline int
__find_bigpair(HTAB *hashp, BUFHEAD *bufp, int ndx, char *key, int size)
{
  uint16_t *bp;
  char *p;
  int ksize;
  uint16_t bytes;
  char *kkey;
  bp = (uint16_t *)bufp->page;
  p = bufp->page;
  ksize = size;
  kkey = key;
  for (bytes = hashp->hdr.bsize - bp[ndx];
       bytes <= size && bp[ndx + 1] == 1 /*PARTIAL_KEY*/;
       bytes = hashp->hdr.bsize - bp[ndx]) {
    if (memcmp(p + bp[ndx], kkey, bytes))
      return (-2);
    kkey += bytes;
    ksize -= bytes;
    bufp = __get_buf(hashp, bp[ndx + 2], bufp, 0);
    if (!bufp)
      return (-3);
    p = bufp->page;
    bp = (uint16_t *)p;
    ndx = 1;
  }
  if (bytes != ksize || memcmp(p + bp[ndx], kkey, bytes)) {
    return (-2);
  } else
  return (ndx);
}

static inline __always_inline uint16_t
__find_last_page(HTAB *hashp, BUFHEAD **bpp)
{
  BUFHEAD *bufp;
  uint16_t *bp, pageno;
  int n;
  bufp = *bpp;
  bp = (uint16_t *)bufp->page;
  for (;;) {
    n = bp[0];
    if (bp[2] == 3 /*FULL_KEY_DATA*/ &&
        ((n == 2) || (bp[n] == 0 /*OVFLPAGE*/) || (DB_FREESPACE(bp))))
      break;
    pageno = bp[n - 1];
    bufp = __get_buf(hashp, pageno, bufp, 0);
    if (!bufp)
      return (0);
    bp = (uint16_t *)bufp->page;
  }
  *bpp = bufp;
  if (bp[0] > 2)
    return (bp[3]);
  else
    return (0);
}

static inline __always_inline int
__buf_free(HTAB *hashp, int do_free, int to_disk)
{
  BUFHEAD *bp;
  if (!hashp->bufhead.prev)
    return (0);
  for (bp = hashp->bufhead.prev; bp != &hashp->bufhead;) {
    if (bp->addr || (bp->flags & BUF_BUCKET)) {
      if (to_disk && (bp->flags & BUF_MOD) &&
          __put_page(hashp, bp->page, bp->addr, (bp->flags & BUF_BUCKET) , 0))
        return (-1);
    }
    if (do_free) {
      if (bp->page) {
        memset(bp->page, 0, hashp->hdr.bsize);
        free(bp->page);
      }
      DB_BUF_REMOVE(bp);
      free(bp);
      bp = hashp->bufhead.prev;
    } else
      bp = bp->prev;
    }
  return (0);
}

static inline __always_inline int
hdestroy(HTAB *hashp)
{
  int i, save_errno;
  save_errno = 0;
  if (__buf_free(hashp, 1, hashp->save_file))
    save_errno = errno;
  if (hashp->dir) {
    free(*hashp->dir);
    while (hashp->exsegs--)
      free(hashp->dir[--hashp->nsegs]);
    free(hashp->dir);
  }
  if (flush_meta(hashp) && !save_errno)
    save_errno = errno;
  for (i = 0; i < hashp->nmaps; i++)
    if (hashp->mapp[i])
      free(hashp->mapp[i]);
  if (hashp->tmp_key)
    free(hashp->tmp_key);
  if (hashp->tmp_buf)
    free(hashp->tmp_buf);
  if (hashp->fp != -1)
    close(hashp->fp);
  free(hashp);
  if (save_errno) {
    errno = save_errno;
    return (DB_ERROR);
  }
  return (DB_SUCCESS);
}

static inline __always_inline void
putpair(char *p, const DBT *key, const DBT *val)
{
  uint16_t *bp, n, off;
  bp = (uint16_t *)p;
  n = bp[0];
  off = DB_OFFSET(bp) - key->size;
  memmove(p + off, key->data, key->size);
  bp[++n] = off;
  off -= val->size;
  memmove(p + off, val->data, val->size);
  bp[++n] = off;
  bp[0] = n;
  bp[n + 1] = off - ((n + 3) * sizeof(uint16_t));
  bp[n + 2] = off;
}

static inline __always_inline uint32_t *
fetch_bitmap(HTAB *hashp, int ndx)
{
  if (ndx >= hashp->nmaps)
    return (NULL);
  if ((hashp->mapp[ndx] = (uint32_t *)malloc(hashp->hdr.bsize)) == NULL)
    return (NULL);
  if (__get_page(hashp,
      (char *)hashp->mapp[ndx], hashp->hdr.bitmaps[ndx], 0, 1, 1)) {
    free(hashp->mapp[ndx]);
    return (NULL);
  }
  return (hashp->mapp[ndx]);
}

static inline __always_inline void *
hash_realloc(SEGMENT **p_ptr, int oldsize, int newsize)
{
  void *p;
  if ( (p = malloc(newsize)) ) {
    memmove(p, *p_ptr, oldsize);
    memset((char *)p + oldsize, 0, newsize - oldsize);
    free(*p_ptr);
    *p_ptr = p;
    }
  return (p);
}

static inline __always_inline uint32_t
__call_hash(HTAB *hashp, char *k, int len)
{
  unsigned int n, bucket;
  n = hashp->hash(k, len);
  bucket = n & hashp->hdr.high_mask;
  if (bucket > hashp->hdr.max_bucket)
    bucket = bucket & hashp->hdr.low_mask;
  return (bucket);
}

static inline __always_inline uint16_t overflow_page(HTAB *hashp);

static inline __always_inline BUFHEAD *
__add_ovflpage(HTAB *hashp, BUFHEAD *bufp)
{
  uint16_t *sp, ndx, ovfl_num;
  sp = (uint16_t *)bufp->page;
  if (hashp->hdr.ffactor == DB_DEF_FFACTOR) {
    hashp->hdr.ffactor = sp[0] >> 1;
    if (hashp->hdr.ffactor < DB_MIN_FFACTOR)
      hashp->hdr.ffactor = DB_MIN_FFACTOR;
  }
  bufp->flags |= BUF_MOD;
  ovfl_num = overflow_page(hashp);
  if (!ovfl_num || !(bufp->ovfl = __get_buf(hashp, ovfl_num, bufp, 1)))
    return (NULL);
  bufp->ovfl->flags |= BUF_MOD;
  ndx = sp[0];
  sp[ndx + 4] = DB_OFFSET(sp);
  sp[ndx + 3] = DB_FREESPACE(sp) - DB_OVFLSIZE;
  sp[ndx + 1] = ovfl_num;
  sp[ndx + 2] = 0 /*OVFLPAGE*/;
  sp[0] = ndx + 2;
  return (bufp->ovfl);
}

static inline __always_inline void
__reclaim_buf(HTAB *hashp, BUFHEAD *bp)
{
  bp->ovfl = 0;
  bp->addr = 0;
  bp->flags = 0;
  DB_BUF_REMOVE(bp);
  DB_LRU_INSERT(bp);
}

static inline __always_inline void
__free_ovflpage(HTAB *hashp, BUFHEAD *obufp)
{
  uint16_t addr;
  uint32_t *freep;
  int bit_address, free_page, free_bit;
  uint16_t ndx;
  addr = obufp->addr;
  ndx = (((uint16_t)addr) >> DB_SPLITSHIFT);
  bit_address = (ndx ? hashp->hdr.spares[ndx - 1] : 0) + (addr & DB_SPLITMASK) - 1;
  if (bit_address < hashp->hdr.last_freed)
    hashp->hdr.last_freed = bit_address;
  free_page = (bit_address >> (hashp->hdr.bshift + DB_BYTE_SHIFT));
  free_bit = bit_address & ((hashp->hdr.bsize << DB_BYTE_SHIFT) - 1);
  if (!(freep = hashp->mapp[free_page]))
    freep = fetch_bitmap(hashp, free_page);
  DB_CLRBIT(freep, free_bit);
  __reclaim_buf(hashp, obufp);
}

static inline __always_inline int
__big_delete(HTAB *hashp, BUFHEAD *bufp)
{
  BUFHEAD *last_bfp, *rbufp;
  uint16_t *bp, pageno;
  int key_done, n;
  rbufp = bufp;
  last_bfp = NULL;
  bp = (uint16_t *)bufp->page;
  pageno = 0;
  key_done = 0;
  while (!key_done || (bp[2] != 3 /*FULL_KEY_DATA*/)) {
    if (bp[2] == 2 /*FULL_KEY*/ || bp[2] == 3 /*FULL_KEY_DATA*/)
      key_done = 1;
    if (bp[2] == 3 /*FULL_KEY_DATA*/ && DB_FREESPACE(bp))
      break;
    pageno = bp[bp[0] - 1];
    rbufp->flags |= BUF_MOD;
    rbufp = __get_buf(hashp, pageno, rbufp, 0);
    if (last_bfp)
      __free_ovflpage(hashp, last_bfp);
    last_bfp = rbufp;
    if (!rbufp)
      return (-1);
    bp = (uint16_t *)rbufp->page;
  }
  n = bp[0];
  pageno = bp[n - 1];
  bp = (uint16_t *)bufp->page;
  if (n > 2) {
    bp[1] = pageno;
    bp[2] = 0 /*OVFLPAGE*/;
    bufp->ovfl = rbufp->ovfl;
  } else
    bufp->ovfl = NULL;
  n -= 2;
  bp[0] = n;
  DB_FREESPACE(bp) = hashp->hdr.bsize - DB_PAGE_META(n);
  DB_OFFSET(bp) = hashp->hdr.bsize;
  bufp->flags |= BUF_MOD;
  if (rbufp)
  __free_ovflpage(hashp, rbufp);
  if (last_bfp && last_bfp != rbufp)
    __free_ovflpage(hashp, last_bfp);
  hashp->hdr.nkeys--;
  return (0);
}

static inline __always_inline int
__delpair(HTAB *hashp, BUFHEAD *bufp, int ndx)
{
  uint16_t *bp, newoff, pairlen;
  int n;
  bp = (uint16_t *)bufp->page;
  n = bp[0];
  if (bp[ndx + 1] < 4 /*REAL_KEY*/)
    return (__big_delete(hashp, bufp));
  if (ndx != 1)
    newoff = bp[ndx - 1];
  else
    newoff = hashp->hdr.bsize;
  pairlen = newoff - bp[ndx + 1];
  if (ndx != (n - 1)) {
    int i;
    char *src = bufp->page + (int)DB_OFFSET(bp);
    char *dst = src + (int)pairlen;
    memmove(dst, src, bp[ndx + 1] - DB_OFFSET(bp));
    for (i = ndx + 2; i <= n; i += 2) {
      if (bp[i + 1] == 0 /*OVFLPAGE*/) {
        bp[i - 2] = bp[i];
        bp[i - 1] = bp[i + 1];
      } else {
        bp[i - 2] = bp[i] + pairlen;
        bp[i - 1] = bp[i + 1] + pairlen;
      }
    }
    if (ndx == hashp->cndx) {
      hashp->cndx -= 2;
    }
  }
  bp[n] = DB_OFFSET(bp) + pairlen;
  bp[n - 1] = bp[n + 1] + pairlen + 2 * sizeof(uint16_t);
  bp[0] = n - 2;
  hashp->hdr.nkeys--;
  bufp->flags |= BUF_MOD;
  return (0);
}

static inline __always_inline int
__big_split(HTAB *hashp, BUFHEAD *op, BUFHEAD *np, BUFHEAD *big_keyp,
    int addr, uint32_t obucket, SPLIT_RETURN *ret)
{
  BUFHEAD *bp, *tmpp;
  DBT key, val;
  uint32_t change;
  uint16_t free_space, n, off, *tp;
  bp = big_keyp;
  if (__big_keydata(hashp, big_keyp, &key, &val, 0))
    return (-1);
  change = (__call_hash(hashp, key.data, key.size) != obucket);
  if ( (ret->next_addr = __find_last_page(hashp, &big_keyp)) ) {
    if (!(ret->nextp = __get_buf(hashp, ret->next_addr, big_keyp, 0)))
      return (-1);
  } else
    ret->nextp = NULL;
  if (change)
    tmpp = np;
  else
    tmpp = op;
  tmpp->flags |= BUF_MOD;
  tmpp->ovfl = bp;
  tp = (uint16_t *)tmpp->page;
  n = tp[0];
  off = DB_OFFSET(tp);
  free_space = DB_FREESPACE(tp);
  tp[++n] = (uint16_t)addr;
  tp[++n] = 0 /*OVFLPAGE*/;
  tp[0] = n;
  DB_OFFSET(tp) = off;
  DB_FREESPACE(tp) = free_space - DB_OVFLSIZE;
  ret->newp = np;
  ret->oldp = op;
  tp = (uint16_t *)big_keyp->page;
  big_keyp->flags |= BUF_MOD;
  if (tp[0] > 2) {
    n = tp[4];
    free_space = DB_FREESPACE(tp);
    off = DB_OFFSET(tp);
    tp[0] -= 2;
    DB_FREESPACE(tp) = free_space + DB_OVFLSIZE;
    DB_OFFSET(tp) = off;
    tmpp = __add_ovflpage(hashp, big_keyp);
    if (!tmpp)
      return (-1);
    tp[4] = n;
  } else
    tmpp = big_keyp;
  if (change)
    ret->newp = tmpp;
  else
    ret->oldp = tmpp;
  return (0);
}

static inline __always_inline int
ugly_split(HTAB *hashp, uint32_t obucket, BUFHEAD *old_bufp, BUFHEAD *new_bufp,
    int copyto, int moved)
{
  BUFHEAD *bufp;
  uint16_t *ino;
  uint16_t *np;
  uint16_t *op;
  BUFHEAD *last_bfp;
  DBT key, val;
  SPLIT_RETURN ret;
  uint16_t n, off, ov_addr, scopyto;
  char *cino;
  bufp = old_bufp;
  ino = (uint16_t *)old_bufp->page;
  np = (uint16_t *)new_bufp->page;
  op = (uint16_t *)old_bufp->page;
  last_bfp = NULL;
  scopyto = (uint16_t)copyto;
  n = ino[0] - 1;
  while (n < ino[0]) {
    if (ino[2] < 4 /*REAL_KEY*/ && ino[2] != 0 /*OVFLPAGE*/) {
      if (__big_split(hashp, old_bufp, new_bufp, bufp, bufp->addr, obucket, &ret))
        return (-1);
      old_bufp = ret.oldp;
      if (!old_bufp)
        return (-1);
      op = (uint16_t *)old_bufp->page;
      new_bufp = ret.newp;
      if (!new_bufp)
        return (-1);
      np = (uint16_t *)new_bufp->page;
      bufp = ret.nextp;
      if (!bufp)
        return (0);
      cino = (char *)bufp->page;
      ino = (uint16_t *)cino;
      last_bfp = ret.nextp;
    } else if (ino[n + 1] == 0 /*OVFLPAGE*/) {
      ov_addr = ino[n];
      ino[0] -= (moved + 2);
      DB_FREESPACE(ino) =
      scopyto - sizeof(uint16_t) * (ino[0] + 3);
      DB_OFFSET(ino) = scopyto;
      bufp = __get_buf(hashp, ov_addr, bufp, 0);
      if (!bufp)
        return (-1);
      ino = (uint16_t *)bufp->page;
      n = 1;
      scopyto = hashp->hdr.bsize;
      moved = 0;
      if (last_bfp)
        __free_ovflpage(hashp, last_bfp);
      last_bfp = bufp;
    }
    off = hashp->hdr.bsize;
    for (n = 1; (n < ino[0]) && (ino[n + 1] >= 4 /*REAL_KEY*/); n += 2) {
      cino = (char *)ino;
      key.data = (unsigned char *)cino + ino[n];
      key.size = off - ino[n];
      val.data = (unsigned char *)cino + ino[n + 1];
      val.size = ino[n] - ino[n + 1];
      off = ino[n + 1];
      if (__call_hash(hashp, key.data, key.size) == obucket) {
        if (DB_PAIRFITS(op, (&key), (&val)))
          putpair((char *)op, &key, &val);
        else {
          old_bufp = __add_ovflpage(hashp, old_bufp);
          if (!old_bufp)
            return (-1);
          op = (uint16_t *)old_bufp->page;
          putpair((char *)op, &key, &val);
        }
        old_bufp->flags |= BUF_MOD;
      } else {
        if (DB_PAIRFITS(np, (&key), (&val)))
          putpair((char *)np, &key, &val);
        else {
          new_bufp = __add_ovflpage(hashp, new_bufp);
          if (!new_bufp)
            return (-1);
          np = (uint16_t *)new_bufp->page;
          putpair((char *)np, &key, &val);
        }
        new_bufp->flags |= BUF_MOD;
      }
    }
  }
  if (last_bfp)
    __free_ovflpage(hashp, last_bfp);
  return (0);
}

static inline __always_inline int
__split_page(HTAB *hashp, uint32_t obucket, uint32_t nbucket)
{
  BUFHEAD *new_bufp, *old_bufp;
  uint16_t *ino;
  char *np;
  DBT key, val;
  int n, ndx, retval;
  uint16_t copyto, diff, off, moved;
  char *op;
  copyto = (uint16_t)hashp->hdr.bsize;
  off = (uint16_t)hashp->hdr.bsize;
  old_bufp = __get_buf(hashp, obucket, NULL, 0);
  if (old_bufp == NULL)
    return (-1);
  new_bufp = __get_buf(hashp, nbucket, NULL, 0);
  if (new_bufp == NULL)
    return (-1);
  old_bufp->flags |= (BUF_MOD | BUF_PIN);
  new_bufp->flags |= (BUF_MOD | BUF_PIN);
  ino = (uint16_t *)(op = old_bufp->page);
  np = new_bufp->page;
  moved = 0;
  for (n = 1, ndx = 1; n < ino[0]; n += 2) {
    if (ino[n + 1] < 4 /*REAL_KEY*/) {
      retval = ugly_split(hashp, obucket, old_bufp, new_bufp,
                          (int)copyto, (int)moved);
      old_bufp->flags &= ~BUF_PIN;
      new_bufp->flags &= ~BUF_PIN;
      return (retval);
    }
    key.data = (unsigned char *)op + ino[n];
    key.size = off - ino[n];
    if (__call_hash(hashp, key.data, key.size) == obucket) {
      diff = copyto - off;
      if (diff) {
        copyto = ino[n + 1] + diff;
        memmove(op + copyto, op + ino[n + 1], off - ino[n + 1]);
        ino[ndx] = copyto + ino[n] - ino[n + 1];
        ino[ndx + 1] = copyto;
      } else
        copyto = ino[n + 1];
      ndx += 2;
    } else {
      val.data = (unsigned char *)op + ino[n + 1];
      val.size = ino[n] - ino[n + 1];
      putpair(np, &key, &val);
      moved += 2;
    }
    off = ino[n + 1];
  }
  ino[0] -= moved;
  DB_FREESPACE(ino) = copyto - sizeof(uint16_t) * (ino[0] + 3);
  DB_OFFSET(ino) = copyto;
  old_bufp->flags &= ~BUF_PIN;
  new_bufp->flags &= ~BUF_PIN;
  return (0);
}

static inline __always_inline int
__expand_table(HTAB *hashp)
{
  uint32_t old_bucket, new_bucket;
  int dirsize, new_segnum, spare_ndx;
  new_bucket = ++hashp->hdr.max_bucket;
  old_bucket = (hashp->hdr.max_bucket & hashp->hdr.low_mask);
  new_segnum = new_bucket >> hashp->hdr.sshift;
  if (new_segnum >= hashp->nsegs) {
    if (new_segnum >= hashp->hdr.dsize) {
      dirsize = hashp->hdr.dsize * sizeof(SEGMENT *);
      if (!hash_realloc(&hashp->dir, dirsize, dirsize << 1))
        return (-1);
      hashp->hdr.dsize = dirsize << 1;
    }
    if ((hashp->dir[new_segnum] =
                    (SEGMENT)calloc(hashp->hdr.ssize, sizeof(SEGMENT))) == NULL)
      return (-1);
    hashp->exsegs++;
    hashp->nsegs++;
  }
  spare_ndx = __dblog2(hashp->hdr.max_bucket + 1);
  if (spare_ndx > hashp->hdr.ovfl_point) {
    hashp->hdr.spares[spare_ndx] = hashp->hdr.spares[hashp->hdr.ovfl_point];
    hashp->hdr.ovfl_point = spare_ndx;
  }
  if (new_bucket > hashp->hdr.high_mask) {
    hashp->hdr.low_mask = hashp->hdr.high_mask;
    hashp->hdr.high_mask = new_bucket | hashp->hdr.low_mask;
  }
  return (__split_page(hashp, old_bucket, new_bucket));
}

#define DB_INT_TO_BYTE  2
#define DB_BYTE_MASK    ((1 << DB_INT_BYTE_SHIFT) -1)
static inline __always_inline int
__ibitmap(HTAB *hashp, int pnum, int nbits, int ndx)
{
  uint32_t *ip;
  int clearbytes, clearints;

  if ((ip = (uint32_t *)malloc(hashp->hdr.bsize)) == NULL)
    return (1);
  hashp->nmaps++;
  clearints = ((nbits - 1) >> DB_INT_BYTE_SHIFT) + 1;
  clearbytes = clearints << DB_INT_TO_BYTE;
  memset((char *)ip, 0, clearbytes);
  memset(((char *)ip) + clearbytes, 0xFF, hashp->hdr.bsize - clearbytes);
  ip[clearints - 1] = DB_ALL_SET << (nbits & DB_BYTE_MASK);
  DB_SETBIT(ip, 0);
  hashp->hdr.bitmaps[ndx] = (uint16_t)pnum;
  hashp->mapp[ndx] = ip;
  return (0);
}

static inline __always_inline uint32_t
first_free(uint32_t map)
{
  uint32_t i, mask;
  mask = 0x1;
  for (i = 0; i < DB_BITS_PER_MAP; i++) {
    if (!(mask & map))
      return (i);
    mask = mask << 1;
  }
  return (i);
}

static inline __always_inline void
squeeze_key(uint16_t *sp, const DBT *key, const DBT *val)
{
  char *p;
  uint16_t free_space, n, off, pageno;
  p = (char *)sp;
  n = sp[0];
  free_space = DB_FREESPACE(sp);
  off = DB_OFFSET(sp);
  pageno = sp[n - 1];
  off -= key->size;
  sp[n - 1] = off;
  memmove(p + off, key->data, key->size);
  off -= val->size;
  sp[n] = off;
  memmove(p + off, val->data, val->size);
  sp[0] = n + 2;
  sp[n + 1] = pageno;
  sp[n + 2] = 0 /*OVFLPAGE*/;
  DB_FREESPACE(sp) = free_space - DB_PAIRSIZE(key, val);
  DB_OFFSET(sp) = off;
}

#define db_rounddown2(x, y) ((x) & ~((y) - 1))

static inline __always_inline uint16_t
overflow_page(HTAB *hashp)
{
  uint32_t *freep __pacify(= NULL);
  int max_free, offset, splitnum;
  uint16_t addr;
  int bit, first_page, free_bit, free_page, i, in_use_bits, j;
  splitnum = hashp->hdr.ovfl_point;
  max_free = hashp->hdr.spares[splitnum];
  free_page = (max_free - 1) >> (hashp->hdr.bshift + DB_BYTE_SHIFT);
  free_bit = (max_free - 1) & ((hashp->hdr.bsize << DB_BYTE_SHIFT) - 1);
  first_page = hashp->hdr.last_freed >>(hashp->hdr.bshift + DB_BYTE_SHIFT);
  for ( i = first_page; i <= free_page; i++ ) {
    if (!(freep = (uint32_t *)hashp->mapp[i]) &&
        !(freep = fetch_bitmap(hashp, i)))
      return (0);
    if (i == free_page)
      in_use_bits = free_bit;
    else
      in_use_bits = (hashp->hdr.bsize << DB_BYTE_SHIFT) - 1;
    if (i == first_page) {
      bit = hashp->hdr.last_freed & ((hashp->hdr.bsize << DB_BYTE_SHIFT) - 1);
      j = bit / DB_BITS_PER_MAP;
      bit = db_rounddown2(bit, DB_BITS_PER_MAP);
    } else {
      bit = 0;
      j = 0;
    }
    for (; bit <= in_use_bits; j++, bit += DB_BITS_PER_MAP)
      if (freep[j] != DB_ALL_SET)
        goto db_ovpage_found;
  }
  hashp->hdr.last_freed = hashp->hdr.spares[splitnum];
  hashp->hdr.spares[splitnum]++;
  offset = hashp->hdr.spares[splitnum] -
           (splitnum ? hashp->hdr.spares[splitnum - 1] : 0);
#define OVMSG   "HASH: Out of overflow pages.  Increase page size\n"
  if (offset > DB_SPLITMASK) {
    if (++splitnum >= NCACHED) {
      write(STDERR_FILENO, OVMSG, sizeof(OVMSG) - 1);
      errno = EFBIG;
      return (0);
    }
    hashp->hdr.ovfl_point = splitnum;
    hashp->hdr.spares[splitnum] = hashp->hdr.spares[splitnum-1];
    hashp->hdr.spares[splitnum-1]--;
    offset = 1;
  }
  if (free_bit == (hashp->hdr.bsize << DB_BYTE_SHIFT) - 1) {
    free_page++;
    if (free_page >= NCACHED) {
      write(STDERR_FILENO, OVMSG, sizeof(OVMSG) - 1);
      errno = EFBIG;
      return (0);
    }
    if (__ibitmap(hashp, (int)DB_OADDR_OF(splitnum, offset), 1, free_page))
      return (0);
    hashp->hdr.spares[splitnum]++;
    offset++;
    if (offset > DB_SPLITMASK) {
      if (++splitnum >= NCACHED) {
        write(STDERR_FILENO, OVMSG, sizeof(OVMSG) - 1);
        errno = EFBIG;
        return (0);
      }
      hashp->hdr.ovfl_point = splitnum;
      hashp->hdr.spares[splitnum] = hashp->hdr.spares[splitnum-1];
      hashp->hdr.spares[splitnum-1]--;
      offset = 0;
    }
  } else {
    free_bit++;
      DB_SETBIT(freep, free_bit);
  }
  addr = DB_OADDR_OF(splitnum, offset);
  return (addr);
db_ovpage_found:
  bit = bit + first_free(freep[j]);
  DB_SETBIT(freep, bit);
  bit = 1 + bit + (i * (hashp->hdr.bsize << DB_BYTE_SHIFT));
  if (bit >= hashp->hdr.last_freed)
    hashp->hdr.last_freed = bit - 1;
  for (i = 0; (i < splitnum) && (bit > hashp->hdr.spares[i]); i++);
  offset = (i ? bit - hashp->hdr.spares[i - 1] : bit);
  if (offset >= DB_SPLITMASK) {
    write(STDERR_FILENO, OVMSG, sizeof(OVMSG) - 1);
    errno = EFBIG;
    return (0);
  }
  addr = DB_OADDR_OF(i, offset);
  return (addr);
}

static inline __always_inline int
__big_insert(HTAB *hashp, BUFHEAD *bufp, const DBT *key, const DBT *val)
{
  uint16_t *p;
  int key_size, n;
  unsigned int val_size;
  uint16_t space, move_bytes, off;
  char *cp, *key_data, *val_data;
  cp = bufp->page;
  p = (uint16_t *)cp;
  key_data = (char *)key->data;
  key_size = key->size;
  val_data = (char *)val->data;
  val_size = val->size;
  for (space = DB_FREESPACE(p) - DB_BIGOVERHEAD; key_size;
       space = DB_FREESPACE(p) - DB_BIGOVERHEAD) {
    move_bytes = MIN(space, key_size);
    off = DB_OFFSET(p) - move_bytes;
    memmove(cp + off, key_data, move_bytes);
    key_size -= move_bytes;
    key_data += move_bytes;
    n = p[0];
    p[++n] = off;
    p[0] = ++n;
    DB_FREESPACE(p) = off - DB_PAGE_META(n);
    DB_OFFSET(p) = off;
    p[n] = 1 /*PARTIAL_KEY*/;
    bufp = __add_ovflpage(hashp, bufp);
    if (!bufp)
      return (-1);
    n = p[0];
    if (!key_size) {
      space = DB_FREESPACE(p);
      if (space) {
        move_bytes = MIN(space, val_size);
        if (space == val_size && val_size == val->size)
          goto db_big_toolarge;
        off = DB_OFFSET(p) - move_bytes;
        memmove(cp + off, val_data, move_bytes);
        val_data += move_bytes;
        val_size -= move_bytes;
        p[n] = off;
        p[n - 2] = 3 /*FULL_KEY_DATA*/;
        DB_FREESPACE(p) = DB_FREESPACE(p) - move_bytes;
        DB_OFFSET(p) = off;
      } else {
db_big_toolarge:
        p[n - 2] = 2 /*FULL_KEY*/;
      }
    }
    p = (uint16_t *)bufp->page;
    cp = bufp->page;
    bufp->flags |= BUF_MOD;
  }
  for (space = DB_FREESPACE(p) - DB_BIGOVERHEAD; val_size;
       space = DB_FREESPACE(p) - DB_BIGOVERHEAD) {
                move_bytes = MIN(space, val_size);
    if (space == val_size && val_size == val->size)
      move_bytes--;
    off = DB_OFFSET(p) - move_bytes;
    memmove(cp + off, val_data, move_bytes);
    val_size -= move_bytes;
    val_data += move_bytes;
    n = p[0];
    p[++n] = off;
    p[0] = ++n;
    DB_FREESPACE(p) = off - DB_PAGE_META(n);
    DB_OFFSET(p) = off;
    if (val_size) {
      p[n] = 2 /*FULL_KEY*/;
      bufp = __add_ovflpage(hashp, bufp);
      if (!bufp)
        return (-1);
      cp = bufp->page;
      p = (uint16_t *)cp;
    } else
      p[n] = 3 /*FULL_KEY_DATA*/;
    bufp->flags |= BUF_MOD;
  }
  return (0);
}

static inline __always_inline int
__addel(HTAB *hashp, BUFHEAD *bufp, const DBT *key, const DBT *val)
{
  uint16_t *bp, *sop;
  int do_expand;
  bp = (uint16_t *)bufp->page;
  do_expand = 0;
  while (bp[0] && (bp[2] < 4 /*REAL_KEY*/ || bp[bp[0]] < 4 /*REAL_KEY*/))
    if (bp[2] == 3 /*FULL_KEY_DATA*/ && bp[0] == 2)
      break;
    else if (bp[2] < 4 /*REAL_KEY*/ && bp[bp[0]] != 0 /*OVFLPAGE*/) {
      bufp = __get_buf(hashp, bp[bp[0] - 1], bufp, 0);
      if (!bufp)
        return (-1);
       bp = (uint16_t *)bufp->page;
    } else if (bp[bp[0]] != 0 /*OVFLPAGE*/) {
      break;
    } else {
      if (bp[2] >= 4 /*REAL_KEY*/ && DB_FREESPACE(bp) >= DB_PAIRSIZE(key, val)) {
        squeeze_key(bp, key, val);
          goto db_addel_stats;
      } else {
        bufp = __get_buf(hashp, bp[bp[0] - 1], bufp, 0);
        if (!bufp)
          return (-1);
        bp = (uint16_t *)bufp->page;
      }
    }
  if (DB_PAIRFITS(bp, key, val))
    putpair(bufp->page, key, val);
  else {
    do_expand = 1;
    bufp = __add_ovflpage(hashp, bufp);
    if (!bufp)
      return (-1);
    sop = (uint16_t *)bufp->page;
    if (DB_PAIRFITS(sop, key, val))
      putpair((char *)sop, key, val);
    else
      if (__big_insert(hashp, bufp, key, val))
        return (-1);
  }
db_addel_stats:
  bufp->flags |= BUF_MOD;
  hashp->hdr.nkeys++;
  if (do_expand ||
      (hashp->hdr.nkeys / (hashp->hdr.max_bucket + 1) > hashp->hdr.ffactor))
    return (__expand_table(hashp));
  return (0);
}

static int
hash_access(HTAB *hashp, ACTION action, DBT *key, DBT *val)
{
  BUFHEAD *rbufp;
  BUFHEAD *bufp, *save_bufp;
  uint16_t *bp;
  int n, ndx, off, size;
  char *kp;
  uint16_t pageno;
  off = hashp->hdr.bsize;
  size = key->size;
  kp = (char *)key->data;
  rbufp = __get_buf(hashp, __call_hash(hashp, kp, size), NULL, 0);
  if (!rbufp)
    return (DB_ERROR);
  save_bufp = rbufp;
  rbufp->flags |= BUF_PIN;
  for (bp = (uint16_t *)rbufp->page, n = *bp++, ndx = 1; ndx < n;)
    if (bp[1] >= 4 /*REAL_KEY*/) {
      if (size == off - *bp && memcmp(kp, rbufp->page + *bp, size) == 0)
        goto db_access_found;
      off = bp[1];
      bp += 2;
      ndx += 2;
    } else if (bp[1] == 0 /*OVFLPAGE*/) {
      rbufp = __get_buf(hashp, *bp, rbufp, 0);
      if (!rbufp) {
        save_bufp->flags &= ~BUF_PIN;
        return (DB_ERROR);
      }
      bp = (uint16_t *)rbufp->page;
      n = *bp++;
      ndx = 1;
      off = hashp->hdr.bsize;
    } else if (bp[1] < 4 /*REAL_KEY*/) {
      if ((ndx = __find_bigpair(hashp, rbufp, ndx, kp, size)) > 0)
        goto db_access_found;
      if (ndx == -2) {
        bufp = rbufp;
        if (!(pageno = __find_last_page(hashp, &bufp))) {
          ndx = 0;
          rbufp = bufp;
          break;
        }
        rbufp = __get_buf(hashp, pageno, bufp, 0);
        if (!rbufp) {
          save_bufp->flags &= ~BUF_PIN;
          return (DB_ERROR);
        }
        bp = (uint16_t *)rbufp->page;
        n = *bp++;
        ndx = 1;
        off = hashp->hdr.bsize;
      } else {
        save_bufp->flags &= ~BUF_PIN;
        return (DB_ERROR);
      }
    }
  switch (action) {
  case HASH_PUT:
  case HASH_PUTNEW:
    if (__addel(hashp, rbufp, key, val)) {
      save_bufp->flags &= ~BUF_PIN;
      return (DB_ERROR);
    } else {
      save_bufp->flags &= ~BUF_PIN;
      return (DB_SUCCESS);
    }
  case HASH_GET:
  case HASH_DELETE:
  default:
    save_bufp->flags &= ~BUF_PIN;
    return (DB_ABNORMAL);
  }
db_access_found:
  switch (action) {
  case HASH_PUTNEW:
    save_bufp->flags &= ~BUF_PIN;
    return (DB_ABNORMAL);
  case HASH_GET:
    bp = (uint16_t *)rbufp->page;
    if (bp[ndx + 1] < 4 /*REAL_KEY*/) {
      if (__big_return(hashp, rbufp, ndx, val, 0))
        return (DB_ERROR);
      } else {
        val->data = (unsigned char *)rbufp->page + (int)bp[ndx + 1];
        val->size = bp[ndx] - bp[ndx + 1];
      }
    break;
  case HASH_PUT:
    if ((__delpair(hashp, rbufp, ndx)) || (__addel(hashp, rbufp, key, val))) {
      save_bufp->flags &= ~BUF_PIN;
      return (DB_ERROR);
    }
    break;
  case HASH_DELETE:
    if (__delpair(hashp, rbufp, ndx))
      return (DB_ERROR);
    break;
  default:
    abort();
  }
  save_bufp->flags &= ~BUF_PIN;
  return (DB_SUCCESS);
}

static inline __always_inline int
hash_get(const DB *dbp, const DBT *key, DBT *data, uint32_t flag)
{
  HTAB *hashp;
  hashp = (HTAB *)dbp->internal;
  if (flag) {
    hashp->error = errno = EINVAL;
    return (DB_ERROR);
  }
  return (hash_access(hashp, HASH_GET, ____DECONST(DBT *, key), data));
}

static inline __always_inline int
hash_put(const DB *dbp, DBT *key, const DBT *data, uint32_t flag)
{
  HTAB *hashp;
  hashp = (HTAB *)dbp->internal;
  if (flag && flag != R_NOOVERWRITE) {
    hashp->error = errno = EINVAL;
    return (DB_ERROR);
  }
  if ((hashp->flags & O_ACCMODE) == O_RDONLY) {
    hashp->error = errno = EPERM;
    return (DB_ERROR);
  }
  return (hash_access(hashp, flag == R_NOOVERWRITE ? HASH_PUTNEW : HASH_PUT,
                      ____DECONST(DBT *, key), ____DECONST(DBT *, data)));
}

static inline __always_inline int
hash_delete(const DB *dbp, const DBT *key, uint32_t flag)
{
  HTAB *hashp;
  hashp = (HTAB *)dbp->internal;
  if (flag && flag != R_CURSOR) {
    hashp->error = errno = EINVAL;
    return (DB_ERROR);
  }
  if ((hashp->flags & O_ACCMODE) == O_RDONLY) {
    hashp->error = errno = EPERM;
    return (DB_ERROR);
  }
  return (hash_access(hashp, HASH_DELETE, ____DECONST(DBT *, key), NULL));
}

static inline __always_inline int
hash_close(DB *dbp)
{
  HTAB *hashp;
  int retval;
  if (!dbp)
    return (DB_ERROR);
  hashp = (HTAB *)dbp->internal;
  retval = hdestroy(hashp);
  free(dbp);
  return (retval);
}

static inline __always_inline int
hash_fd(const DB *dbp)
{
  HTAB *hashp;
  if (!dbp)
    return (DB_ERROR);
  hashp = (HTAB *)dbp->internal;
  if (hashp->fp == -1) {
    errno = ENOENT;
    return (-1);
  }
  return (hashp->fp);
}

static inline __always_inline int
hash_seq(const DB *dbp, DBT *key, DBT *data, uint32_t flag)
{
  uint32_t bucket;
  BUFHEAD *bufp;
  HTAB *hashp;
  uint16_t *bp, ndx;
  hashp = (HTAB *)dbp->internal;
  if (flag && flag != R_FIRST && flag != R_NEXT) {
    hashp->error = errno = EINVAL;
    return (DB_ERROR);
  }
  if ((hashp->cbucket < 0) || (flag == R_FIRST)) {
    hashp->cbucket = 0;
    hashp->cndx = 1;
    hashp->cpage = NULL;
  }
next_bucket:
  for (bp = NULL; !bp || !bp[0]; ) {
    if (!(bufp = hashp->cpage)) {
      for (bucket = hashp->cbucket; bucket <= hashp->hdr.max_bucket;
           bucket++, hashp->cndx = 1) {
        bufp = __get_buf(hashp, bucket, NULL, 0);
        if (!bufp)
          return (DB_ERROR);
        hashp->cpage = bufp;
        bp = (uint16_t *)bufp->page;
        if (bp[0])
          break;
      }
      hashp->cbucket = bucket;
      if ((uint32_t)hashp->cbucket > hashp->hdr.max_bucket) {
        hashp->cbucket = -1;
        return (DB_ABNORMAL);
      }
    } else {
      bp = (uint16_t *)hashp->cpage->page;
      if (flag == R_NEXT || flag == 0) {
        hashp->cndx += 2;
        if (hashp->cndx > bp[0]) {
          hashp->cpage = NULL;
          hashp->cbucket++;
          hashp->cndx = 1;
          goto next_bucket;
        }
      }
    }
    while (bp[hashp->cndx + 1] == 0 /*OVFLPAGE*/) {
      bufp = hashp->cpage =
      __get_buf(hashp, bp[hashp->cndx], bufp, 0);
      if (!bufp)
        return (DB_ERROR);
      bp = (uint16_t *)(bufp->page);
      hashp->cndx = 1;
    }
    if (!bp[0]) {
      hashp->cpage = NULL;
      ++hashp->cbucket;
    }
  }
  ndx = hashp->cndx;
  if (bp[ndx + 1] < 4 /*REAL_KEY*/) {
    if (__big_keydata(hashp, bufp, key, data, 1))
      return (DB_ERROR);
  } else {
    if (hashp->cpage == 0)
      return (DB_ERROR);
    key->data = (unsigned char *)hashp->cpage->page + bp[ndx];
    key->size = (ndx > 1 ? bp[ndx - 1] : hashp->hdr.bsize) - bp[ndx];
    data->data = (unsigned char *)hashp->cpage->page + bp[ndx + 1];
    data->size = bp[ndx] - bp[ndx + 1];
  }
  return (DB_SUCCESS);
}

static inline __always_inline int
alloc_segs(HTAB *hashp, int nsegs)
{
  int i;
  SEGMENT store;
  int save_errno;
  if ((hashp->dir =
      (SEGMENT *)calloc(hashp->hdr.dsize, sizeof(SEGMENT *))) == NULL) {
    save_errno = errno;
    hdestroy(hashp);
    errno = save_errno;
    return (-1);
  }
  hashp->nsegs = nsegs;
  if (nsegs == 0)
    return (0);
  if ((store = (SEGMENT)calloc(nsegs << hashp->hdr.sshift,
               sizeof(SEGMENT))) == NULL) {
    save_errno = errno;
    hdestroy(hashp);
    errno = save_errno;
    return (-1);
  }
  for (i = 0; i < nsegs; i++)
    hashp->dir[i] = &store[i << hashp->hdr.sshift];
  return (0);
}

static inline __always_inline int
init_htab(HTAB *hashp, int nelem)
{
  int nbuckets, nsegs, l2;
  nelem = (nelem - 1) / hashp->hdr.ffactor + 1;
  l2 = __dblog2(MAX(nelem, 2));
  nbuckets = 1 << l2;
  hashp->hdr.spares[l2] = l2 + 1;
  hashp->hdr.spares[l2 + 1] = l2 + 1;
  hashp->hdr.ovfl_point = l2;
  hashp->hdr.last_freed = 2;
  if (__ibitmap(hashp, DB_OADDR_OF(l2, 1), l2 + 1, 0))
    return (-1);
  hashp->hdr.max_bucket = hashp->hdr.low_mask = nbuckets - 1;
  hashp->hdr.high_mask = (nbuckets << 1) - 1;
  hashp->hdr.hdrpages = ((MAX(sizeof(HASHHDR), DB_MINHDRSIZE) - 1) >>
                         hashp->hdr.bshift) + 1;
  nsegs = (nbuckets - 1) / hashp->hdr.ssize + 1;
  nsegs = 1 << __dblog2(nsegs);
  if (nsegs > hashp->hdr.dsize)
    hashp->hdr.dsize = nsegs;
  return (alloc_segs(hashp, nsegs));
}

static inline __always_inline HTAB *
init_hash(HTAB *hashp, const char *file, const HASHINFO *info)
{
  struct stat statbuf;
  int nelem;
  nelem = 1;
  hashp->hdr.nkeys = 0;
  hashp->hdr.lorder = BYTE_ORDER;
  hashp->hdr.bsize = DB_DEF_BUCKET_SIZE;
  hashp->hdr.bshift = DB_DEF_BUCKET_SHIFT;
  hashp->hdr.ssize = DB_DEF_SEGSIZE;
  hashp->hdr.sshift = DB_DEF_SEGSIZE_SHIFT;
  hashp->hdr.dsize = DB_DEF_DIRSIZE;
  hashp->hdr.ffactor = DB_DEF_FFACTOR;
  hashp->hash = __default_hash;
  memset(hashp->hdr.spares, 0, sizeof(hashp->hdr.spares));
  memset(hashp->hdr.bitmaps, 0, sizeof (hashp->hdr.bitmaps));
  if (file != NULL) {
    if (stat(file, &statbuf))
      return (NULL);
    hashp->hdr.bsize = DB_NOM_BSIZE;
    if (hashp->hdr.bsize > DB_MAX_BSIZE)
      hashp->hdr.bsize = DB_MAX_BSIZE;
    hashp->hdr.sshift = __dblog2(hashp->hdr.bsize);
  }
  if (info) {
    if (info->bsize) {
      hashp->hdr.sshift = __dblog2(info->bsize);
      hashp->hdr.bsize = 1 << hashp->hdr.bshift;
      if (hashp->hdr.bsize > DB_MAX_BSIZE) {
        errno = EINVAL;
        return (NULL);
      }
    }
    if (info->ffactor)
      hashp->hdr.ffactor = info->ffactor;
    if (info->hash)
      hashp->hash = info->hash;
    if (info->nelem)
      nelem = info->nelem;
    if (info->lorder) {
      if (info->lorder != BIG_ENDIAN &&
          info->lorder != LITTLE_ENDIAN) {
        errno = EINVAL;
        return (NULL);
      }
    hashp->hdr.lorder = info->lorder;
    }
  }
  if (init_htab(hashp, nelem))
    return (NULL);
  else
    return (hashp);
}

static inline __always_inline int
hash_sync(const DB *dbp, uint32_t flags)
{
  HTAB *hashp;
  if (flags != 0) {
    errno = EINVAL;
    return (DB_ERROR);
  }
  if (!dbp)
    return (DB_ERROR);
  hashp = (HTAB *)dbp->internal;
  if (!hashp->save_file)
    return (0);
  if (__buf_free(hashp, 0, 1) || flush_meta(hashp))
    return (DB_ERROR);
  hashp->new_file = 0;
  return (0);
}

static inline __always_inline DB *
__hash_open(const char *file, int flags, mode_t mode,
    const HASHINFO *info, int dflags ____unused)
{
  HTAB *hashp;
  struct stat statbuf;
  DB *dbp;
  int bpages, hdrsize, new_table, nsegs, save_errno;
  if ((flags & O_ACCMODE) == O_WRONLY) {
    errno = EINVAL;
    return (NULL);
  }
  if (!(hashp = (HTAB *)calloc(1, sizeof(HTAB))))
    return (NULL);
  hashp->fp = -1;
  hashp->flags = flags;
  if (file) {
    if ((hashp->fp = open(file, flags | O_CLOEXEC, mode)) == -1)
      DB_RETURN_ERROR(errno, dberror0);
    fcntl(hashp->fp, F_SETFD, 1);
    new_table = fstat(hashp->fp, &statbuf) == 0 &&
                      statbuf.st_size == 0 && (flags & O_ACCMODE) != O_RDONLY;
  } else
    new_table = 1;
  if (new_table) {
    if (!(hashp = init_hash(hashp, file, info)))
      DB_RETURN_ERROR(errno, dberror1);
  } else {
    if (info && info->hash)
      hashp->hash = info->hash;
    else
      hashp->hash = __default_hash;
    hdrsize = read(hashp->fp, &hashp->hdr, sizeof(HASHHDR));
#if __BYTE_ORDER == __LITTLE_ENDIAN
    swap_header(hashp);
#endif
    if (hdrsize == -1)
      DB_RETURN_ERROR(errno, dberror1);
    if (hdrsize != sizeof(HASHHDR))
      DB_RETURN_ERROR(EFTYPE, dberror1);
    if (hashp->hdr.magic != HASHMAGIC)
      DB_RETURN_ERROR(EFTYPE, dberror1);
#define OLDHASHVERSION  1
    if (hashp->hdr.version != HASHVERSION &&
        hashp->hdr.version != OLDHASHVERSION)
      DB_RETURN_ERROR(EFTYPE, dberror1);
    if ((int32_t)hashp->hash(DB_CHARKEY, sizeof(DB_CHARKEY)) != hashp->hdr.h_charkey)
      DB_RETURN_ERROR(EFTYPE, dberror1);
    nsegs = (hashp->hdr.max_bucket + 1 + hashp->hdr.ssize - 1) / hashp->hdr.ssize;
    if (alloc_segs(hashp, nsegs))
      return (NULL);
    bpages = (hashp->hdr.spares[hashp->hdr.ovfl_point] +
             (hashp->hdr.bsize << DB_BYTE_SHIFT) - 1) >>
             (hashp->hdr.bshift + DB_BYTE_SHIFT);
    hashp->nmaps = bpages;
    memset(&hashp->mapp[0], 0, bpages * sizeof(uint32_t *));
  }
  if (info && info->cachesize)
    __buf_init(hashp, info->cachesize);
  else
    __buf_init(hashp, DB_DEF_BUFSIZE);
  hashp->new_file = new_table;
  hashp->save_file = file && (hashp->flags & O_RDWR);
  hashp->cbucket = -1;
  if (!(dbp = (DB *)malloc(sizeof(DB)))) {
    save_errno = errno;
    hdestroy(hashp);
    errno = save_errno;
    return (NULL);
  }
  dbp->internal = hashp;
  dbp->close = hash_close;
  dbp->del = hash_delete;
  dbp->fd = hash_fd;
  dbp->get = hash_get;
  dbp->put = hash_put;
  dbp->seq = hash_seq;
  dbp->sync = hash_sync;
  dbp->type = DB_HASH;
  return (dbp);

dberror1:
  if (hashp != NULL)
    close(hashp->fp);

dberror0:
  free(hashp);
  errno = save_errno;
  return (NULL);
}

static inline __always_inline DB *
dbopen(const char *fname, int flags, mode_t mode, DBTYPE type, const void *info)
{
#define DB_FLAGS        (DB_LOCK | DB_SHMEM | DB_TXN)
#define USE_OPEN_FLAGS                                                  \
    (O_CREAT | O_EXCL | O_EXLOCK | O_NOFOLLOW | O_NONBLOCK |        \
    O_RDONLY | O_RDWR | O_SHLOCK | O_SYNC | O_TRUNC | O_CLOEXEC)
  if ((flags & ~(USE_OPEN_FLAGS | DB_FLAGS)) == 0)
    switch (type) {
#if 0
    case DB_BTREE:
      return (__bt_open(fname, flags & USE_OPEN_FLAGS,
              mode, info, flags & DB_FLAGS));
#endif
    case DB_HASH:
      return (__hash_open(fname, flags & USE_OPEN_FLAGS,
              mode, info, flags & DB_FLAGS));
#if 0
    case DB_RECNO:
      return (__rec_open(fname, flags & USE_OPEN_FLAGS,
              mode, info, flags & DB_FLAGS));
#endif
    default:
      break;
    }
  errno = EINVAL;
  return (NULL);
}

/* for cap_mkdb(1) */
#include <strings.h>

#define DB_MAX_RECURSION   32

typedef uint32_t        recno_t;

static size_t    topreclen;
static char     *toprec;
static int       gottoprec;

static FILE *pfp;
static int slash;
static char **dbp;

static inline __always_inline void *
reallocf(void *ptr, size_t size)
{
  void *nptr;
  nptr = realloc(ptr, size);
  if (!nptr && ptr)
    free(ptr);
  return (nptr);
}

static inline __always_inline int
nfcmp(char *nf, char *rec)
{
  char *cp, tmp;
  int ret;
  for (cp = rec; *cp != ':'; cp++);
  tmp = *(cp + 1);
  *(cp + 1) = '\0';
  ret = strcmp(nf, rec);
  *(cp + 1) = tmp;
  return (ret);
}


static inline __always_inline int
cgetclose(void)
{
  if (pfp != NULL) {
    fclose(pfp);
    pfp = NULL;
  }
  dbp = NULL;
  gottoprec = 0;
  slash = 0;
  return(0);
}

static inline __always_inline int
cgetset(const char *ent)
{
  if (ent == NULL) {
    if (toprec)
      free(toprec);
    toprec = NULL;
    topreclen = 0;
    return (0);
  }
  topreclen = strlen(ent);
  if ((toprec = malloc (topreclen + 1)) == NULL) {
    errno = ENOMEM;
    return (-1);
  }
  gottoprec = 0;
  strcpy(toprec, ent);
  return (0);
}

static inline __always_inline char *
cgetcap(char *buf, const char *cap, int type)
{
  char *bp;
  const char *cp;
  bp = buf;
  for (;;) {
    for (;;)
      if (*bp == '\0')
        return (NULL);
      else
        if (*bp++ == ':')
    break;
    for (cp = cap; *cp == *bp && *bp != '\0'; cp++, bp++)
      continue;
    if (*cp != '\0')
      continue;
    if (*bp == '@')
      return (NULL);
    if (type == ':') {
      if (*bp != '\0' && *bp != ':')
        continue;
      return(bp);
    }
    if (*bp != type)
      continue;
    bp++;
    return (*bp == '@' ? NULL : bp);
  }
  /* NOTREACHED */
}

static inline __always_inline int
cgetmatch(const char *buf, const char *name)
{
  const char *np, *bp;
  if (name == NULL || *name == '\0')
    return -1;
  bp = buf;
  for (;;) {
    np = name;
    for (;;)
      if (*np == '\0')
        if (*bp == '|' || *bp == ':' || *bp == '\0')
          return (0);
        else
          break;
       else
         if (*bp++ != *np++)
           break;
    bp--;
    for (;;)
      if (*bp == '\0' || *bp == ':')
        return (-1);
      else
        if (*bp++ == '|')
          break;
  }
}

static inline __always_inline int
cdbget(DB *capdbp, char **bp, const char *name)
{
  DBT key, data;
  char *namebuf;
  namebuf = strdup(name);
  if (namebuf == NULL)
    return (-2);
  key.data = namebuf;
  key.size = strlen(namebuf);
  for (;;) {
    switch(capdbp->get(capdbp, &key, &data, 0)) {
    case -1:
      free(namebuf);
      return (-2);
    case 1:
      free(namebuf);
      return (-1);
    }
    if (((char *)data.data)[0] != (char)2 /*SHADOW*/)
      break;
    key.data = (char *)data.data + 1;
    key.size = data.size - 1;
  }
  *bp = (char *)data.data + 1;
  free(namebuf);
  return (((char *)(data.data))[0] == (char)1 /*TCERR*/ ? 1 : 0);
}

static int getent(char **cap, u_int *len, char **db_array, int fd, const char *name,
       int depth, char *nfield);

static int
getent(char **cap, u_int *len, char **db_array, int fd, const char *name,
       int depth, char *nfield)
{
  DB *capdbp;
  char *r_end, *rp, **db_p;
  int myfd, eof, foundit, retval, clen;
  char *record, *cbuf;
  int tc_not_resolved;
  char pbuf[_POSIX_PATH_MAX];
  rp = NULL;
  myfd = 0;
  if (depth > DB_MAX_RECURSION)
    return (-3);
  if (depth == 0 && toprec != NULL && cgetmatch(toprec, name) == 0) {
    if ((record = malloc (topreclen + 1024 /*BFRAG*/)) == NULL) {
      errno = ENOMEM;
      return (-2);
    }
    strcpy(record, toprec);
    myfd = 0;
    db_p = db_array;
    rp = record + topreclen + 1;
    r_end = rp + 1024 /*BFRAG*/;
    goto tc_exp;
  }
  if ((record = malloc(1024 /*BFRAG*/)) == NULL) {
    errno = ENOMEM;
    return (-2);
  }
  r_end = record + 1024 /*BFRAG*/;
  foundit = 0;
  for (db_p = db_array; *db_p != NULL; db_p++) {
    eof = 0;
    if (fd >= 0) {
      lseek(fd, (off_t)0, SEEK_SET);
      myfd = 0;
    } else {
      snprintf(pbuf, sizeof(pbuf), "%s.db", *db_p);
      if ((capdbp = dbopen(pbuf, O_RDONLY, 0, DB_HASH, 0)) != NULL) {
        free(record);
        retval = cdbget(capdbp, &record, name);
        if (retval < 0) {
          capdbp->close(capdbp);
          return (retval);
        }
        clen = strlen(record);
        cbuf = malloc(clen + 1);
        memcpy(cbuf, record, clen + 1);
        if (capdbp->close(capdbp) < 0) {
          free(cbuf);
          return (-2);
        }
        *len = clen;
        *cap = cbuf;
        return (retval);
      } else {
        fd = open(*db_p, O_RDONLY | O_CLOEXEC, 0);
        if (fd < 0)
          continue;
        myfd = 1;
      }
    }
    {
      char buf[BUFSIZ];
      char *b_end, *bp;
      int c;
      b_end = buf;
      bp = buf;
      for (;;) {
        rp = record;
        for (;;) {
          if (bp >= b_end) {
            int n;
            n = read(fd, buf, sizeof(buf));
            if (n <= 0) {
              if (myfd)
                close(fd);
              if (n < 0) {
                free(record);
                return (-2);
              } else {
                fd = -1;
                eof = 1;
                break;
              }
            }
            b_end = buf+n;
            bp = buf;
          }
          c = *bp++;
          if (c == '\n') {
            if (rp > record && *(rp-1) == '\\') {
              rp--;
              continue;
            } else
              break;
          }
          *rp++ = c;
          if (rp >= r_end) {
            unsigned int pos;
            size_t newsize;
            pos = rp - record;
            newsize = r_end - record + 1024 /*BFRAG*/;
            record = reallocf(record, newsize);
            if (record == NULL) {
              errno = ENOMEM;
              if (myfd)
                close(fd);
              return (-2);
            }
            r_end = record + newsize;
            rp = record + pos;
          }
        }
        *rp++ = '\0';
        if (eof)
          break;
        if (*record == '\0' || *record == '#')
          continue;
        if (cgetmatch(record, name) == 0) {
          if (nfield == NULL || !nfcmp(nfield, record)) {
            foundit = 1;
            break;
          }
        }
      }
    }
    if (foundit)
      break;
  }
  if (!foundit) {
    free(record);
    return (-1);
  }
tc_exp:
  {
    char *newicap, *s;
    int newilen;
    unsigned int ilen;
    int diff, iret, tclen;
    char *icap, *scan, *tc, *tcstart, *tcend;
    scan = record;
    tc_not_resolved = 0;
    for (;;) {
    if ((tc = cgetcap(scan, "tc", '=')) == NULL)
      break;
    s = tc;
      for (;;)
    if (*s == '\0')
      break;
    else
      if (*s++ == ':') {
        *(s - 1) = '\0';
        break;
      }
    tcstart = tc - 3;
    tclen = s - tcstart;
    tcend = s;
    iret = getent(&icap, &ilen, db_p, fd, tc, depth+1, NULL);
    newicap = icap;
    newilen = ilen;
    if (iret != 0) {
      if (iret < -1) {
        if (myfd)
          close(fd);
        free(record);
        return (iret);
      }
      if (iret == 1)
        tc_not_resolved = 1;
      if (iret == -1) {
        *(s - 1) = ':';
        scan = s - 1;
        tc_not_resolved = 1;
        continue;
      }
    }
    s = newicap;
    for (;;)
      if (*s == '\0')
        break;
      else
        if (*s++ == ':')
          break;
    newilen -= s - newicap;
    newicap = s;
    s += newilen;
    if (*(s-1) != ':') {
      *s = ':';
      newilen++;
    }
    diff = newilen - tclen;
    if (diff >= r_end - rp) {
      unsigned int pos, tcpos, tcposend;
      size_t newsize;
      pos = rp - record;
      newsize = r_end - record + diff + 1024 /*BFRAG*/;
      tcpos = tcstart - record;
      tcposend = tcend - record;
      record = reallocf(record, newsize);
      if (record == NULL) {
        errno = ENOMEM;
        if (myfd)
          close(fd);
        free(icap);
        return (-2);
      }
      r_end = record + newsize;
      rp = record + pos;
      tcstart = record + tcpos;
      tcend = record + tcposend;
    }
    s = tcstart + newilen;
    bcopy(tcend, s, rp - tcend);
    bcopy(newicap, tcstart, newilen);
    rp += diff;
    free(icap);
    scan = s-1;
    }
  }
  if (myfd)
    close(fd);
  *len = rp - record - 1;
  if (r_end > rp)
    if ((record = reallocf(record, (size_t)(rp - record))) == NULL) {
      errno = ENOMEM;
      return (-2);
    }
  *cap = record;
  if (tc_not_resolved)
    return (1);
  return (0);
}

static inline __always_inline int
cgetent(char **buf, char **db_array, const char *name)
{
  unsigned int dummy;
  return (getent(buf, &dummy, db_array, -1, name, 0, NULL));
}

static inline __always_inline int
cgetnext(char **bp, char **db_array)
{
  size_t len;
  int done, hadreaderr, savederrno, status;
  char *cp, *line, *rp, *np, buf[1024 /*BSIZE*/], nbuf[1024 /*BSIZE*/];
  unsigned int dummy;
  savederrno = 0;
  if (dbp == NULL)
    dbp = db_array;
  if (pfp == NULL && (pfp = fopen(*dbp, "r")) == NULL) {
    cgetclose();
    return (-1);
  }
  for(;;) {
    if (toprec && !gottoprec) {
      gottoprec = 1;
      line = toprec;
    } else {
      line = fgetln(pfp, &len);
      if (line == NULL && pfp) {
        hadreaderr = ferror(pfp);
        if (hadreaderr)
          savederrno = errno;
        fclose(pfp);
        pfp = NULL;
        if (hadreaderr) {
          cgetclose();
          errno = savederrno;
          return (-1);
        } else {
          if (*++dbp == NULL) {
            cgetclose();
            return (0);
          } else if ((pfp = fopen(*dbp, "r")) == NULL) {
            cgetclose();
            return (-1);
          } else
          continue;
        }
      } else
        line[len - 1] = '\0';
      if (len == 1) {
        slash = 0;
        continue;
      }
      if (isspace((unsigned char)*line) ||
          *line == ':' || *line == '#' || slash) {
        if (line[len - 2] == '\\')
          slash = 1;
        else
          slash = 0;
        continue;
      }
      if (line[len - 2] == '\\')
        slash = 1;
      else
        slash = 0;
    }
    done = 0;
    np = nbuf;
    for (;;) {
      for (cp = line; *cp != '\0'; cp++) {
        if (*cp == ':') {
          *np++ = ':';
          done = 1;
          break;
        }
        if (*cp == '\\')
          break;
        *np++ = *cp;
      }
      if (done) {
        *np = '\0';
         break;
      } else {
        line = fgetln(pfp, &len);
        if (line == NULL && pfp) {
          hadreaderr = ferror(pfp);
          if (hadreaderr)
            savederrno = errno;
          fclose(pfp);
          pfp = NULL;
          if (hadreaderr) {
            cgetclose();
            errno = savederrno;
            return (-1);
          } else {
            cgetclose();
            return (-1);
          }
        } else
          line[len - 1] = '\0';
      }
    }
    rp = buf;
    for(cp = nbuf; *cp != '\0'; cp++)
      if (*cp == '|' || *cp == ':')
        break;
      else
        *rp++ = *cp;
    *rp = '\0';
    status = getent(bp, &dummy, db_array, -1, buf, 0, NULL);
    if (status == -2 || status == -3)
      cgetclose();
    return (status + 1);
  }
  /* NOTREACHED */
}
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/inlined/err.hi
#ifdef __linux__
#include <sys/cdefs.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

static FILE *err_file;
static void (*err_exit)(int);

static inline __always_inline void
err_set_file(void *fp)
{
  if (fp)
    err_file = fp;
  else
    err_file = stderr;
}

static inline __always_inline void
err_set_exit(void (*ef)(int))
{
  err_exit = ef;
}


static inline __always_inline void
verrc(int eval, int code, const char *fmt, va_list ap)
{
  if (err_file == NULL)
    err_set_file(NULL);
  fprintf(err_file, "%s: ", getprogname());
  if (fmt != NULL) {
    vfprintf(err_file, fmt, ap);
    fprintf(err_file, ": ");
  }
  fprintf(err_file, "%s\n", strerror(code));
  if (err_exit)
    err_exit(eval);
  exit(eval);
}

static void
errc(int eval, int code, const char *fmt, ...)
{
  va_list ap;
  va_start(ap, fmt);
  verrc(eval, code, fmt, ap);
  va_end(ap);
}

static inline __always_inline void
__dummy_errc(void)
{
  errc(1,1,NULL);
}

static inline __always_inline void
vwarnc(int code, const char *fmt, va_list ap)
{
  if (err_file == NULL)
    err_set_file(NULL);
  fprintf(err_file, "%s: ", getprogname());
  if (fmt != NULL) {
    vfprintf(err_file, fmt, ap);
    fprintf(err_file, ": ");
  }
  fprintf(err_file, "%s\n", strerror(code));
}


static void
warnc(int code, const char *fmt, ...)
{
  va_list ap;
  va_start(ap, fmt);
  vwarnc(code, fmt, ap);
  va_end(ap);
}

static inline __always_inline void
__dummy_warnc(void)
{
  warnc(1, NULL);
}
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/inlined/resolv.hi
#ifdef __linux__
#undef b64_ntop
#undef b64_pton
#include <sys/cdefs.h>
#include <ctype.h>
#include <stddef.h>
#include <string.h>

static const char __Base64[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static const char __Pad64 = '=';

static inline __always_inline int /* needed for uuencode */
b64_ntop(u_char const *src, size_t srclength, char *target, size_t targsize)
{
  size_t datalength = 0;
  unsigned char input[3];
  unsigned char output[4];
  size_t i;
  while (2 < srclength) {
    input[0] = *src++;
    input[1] = *src++;
    input[2] = *src++;
    srclength -= 3;
    output[0] = input[0] >> 2;
    output[1] = ((input[0] & 0x03) << 4) + (input[1] >> 4);
    output[2] = ((input[1] & 0x0f) << 2) + (input[2] >> 6);
    output[3] = input[2] & 0x3f;
    if (datalength + 4 > targsize)
      return (-1);
    target[datalength++] = __Base64[output[0]];
    target[datalength++] = __Base64[output[1]];
    target[datalength++] = __Base64[output[2]];
    target[datalength++] = __Base64[output[3]];
  }
  if (0 != srclength) {
    input[0] = input[1] = input[2] = '\0';
    for (i = 0; i < srclength; i++)
      input[i] = *src++;
    output[0] = input[0] >> 2;
    output[1] = ((input[0] & 0x03) << 4) + (input[1] >> 4);
    output[2] = ((input[1] & 0x0f) << 2) + (input[2] >> 6);
    if (datalength + 4 > targsize)
      return (-1);
    target[datalength++] = __Base64[output[0]];
    target[datalength++] = __Base64[output[1]];
    if (srclength == 1)
      target[datalength++] = __Pad64;
    else
      target[datalength++] = __Base64[output[2]];
    target[datalength++] = __Pad64;
  }
  if (datalength >= targsize)
    return (-1);
  target[datalength] = '\0';
  return (datalength);
}

static inline __always_inline int /* needed for uudecode */
b64_pton(char const *src, unsigned char *target, size_t targsize)
{
  int tarindex, state, ch;
  char *pos;
  state = 0;
  tarindex = 0;
  while ((ch = *src++) != '\0') {
    if (isspace((unsigned char)ch))
      continue;
    if (ch == __Pad64)
      break;
    pos = strchr(__Base64, ch);
    if (pos == NULL)
      return (-1);
    switch (state) {
    case 0:
      if (target) {
        if ((size_t)tarindex >= targsize)
          return (-1);
        target[tarindex] = (pos - __Base64) << 2;
      }
      state = 1;
      break;
    case 1:
      if (target) {
        if ((size_t)tarindex + 1 >= targsize)
          return (-1);
        target[tarindex]   |=  (pos - __Base64) >> 4;
        target[tarindex+1]  = ((pos - __Base64) & 0x0f) << 4 ;
      }
      tarindex++;
      state = 2;
      break;
    case 2:
      if (target) {
        if ((size_t)tarindex + 1 >= targsize)
          return (-1);
        target[tarindex]   |=  (pos - __Base64) >> 2;
        target[tarindex+1]  = ((pos - __Base64) & 0x03) << 6;
      }
      tarindex++;
      state = 3;
      break;
    case 3:
      if (target) {
        if ((size_t)tarindex >= targsize)
          return (-1);
        target[tarindex] |= (pos - __Base64);
      }
      tarindex++;
      state = 0;
      break;
    default:
      abort();
    }
  }
  if (ch == __Pad64) {
    ch = *src++;
    switch (state) {
    case 0:
    case 1:
      return (-1);
    case 2:
      for ((void)NULL; ch != '\0'; ch = *src++)
        if (!isspace((unsigned char)ch))
          break;
      if (ch != __Pad64)
        return (-1);
      ch = *src++;
      /* FALLTHROUGH */
    case 3:
      for ((void)NULL; ch != '\0'; ch = *src++)
        if (!isspace((unsigned char)ch))
          return (-1);
      if (target && target[tarindex] != 0)
        return (-1);
    }
  } else {
    if (state != 0)
     return (-1);
  }
  return (tarindex);
}
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/inlined/stdio.hi
#ifdef __linux__
#include <sys/cdefs.h>
#include <stdlib.h>
#include <errno.h>
/* work around for sort(1) and cap_mkdb(1) and citrus/mkscmapper */
/*#if defined(WITHOUT_NLS) || defined(__compat_db_h__) || defined(USES_CITRUS)*/
#define FILEBUF_POOL_ITEMS 32

#if defined(WITHOUT_NLS) /* for sort(1) */
#include <wchar.h>
#define __MUL_NO_OVERFLOW ((size_t)1 << (sizeof(size_t) * 4))
static inline __always_inline void *
__reallocarray(void *ptr, size_t number, size_t size)
{
  if ((number >= __MUL_NO_OVERFLOW || size >= __MUL_NO_OVERFLOW) &&
       number > 0 && SIZE_MAX / number < size) {
    errno = ENOMEM;
    return NULL;
  }
  return realloc(ptr, size * number);
}
struct filewbuf {
  FILE *fp;
  wchar_t *wbuf;
  size_t len;
};

#define FILEWBUF_INIT_LEN     128
#define FILEWBUF_POOL_ITEMS   32

static struct filewbuf fbw_pool[FILEWBUF_POOL_ITEMS];
static int fbw_pool_cur;

static inline __always_inline wchar_t *
fgetwln(FILE *stream, size_t *lenp)
{
  struct filewbuf *fb;
  wint_t wc;
  size_t wused = 0;
  fb = &fbw_pool[fbw_pool_cur];
  if (fb->fp != stream && fb->fp != NULL) {
    fbw_pool_cur++;
    fbw_pool_cur %= FILEWBUF_POOL_ITEMS;
    fb = &fbw_pool[fbw_pool_cur];
  }
  fb->fp = stream;
  while ((wc = fgetwc(stream)) != WEOF) {
    if (!fb->len || wused >= fb->len) {
      wchar_t *wp;
      if (fb->len)
        fb->len *= 2;
      else
        fb->len = FILEWBUF_INIT_LEN;
      wp = __reallocarray(fb->wbuf, fb->len, sizeof(wchar_t));
      if (wp == NULL) {
        wused = 0;
        break;
      }
      fb->wbuf = wp;
    }
    fb->wbuf[wused++] = wc;
    if (wc == L'\n')
      break;
  }
  *lenp = wused;
  return wused ? fb->wbuf : NULL;
}
#endif

struct filebuf {
    FILE *fp;
    char *buf;
    size_t len;
};

static struct filebuf fb_pool[FILEBUF_POOL_ITEMS];
static int fb_pool_cur;

static inline __always_inline char *
fgetln(FILE *stream, size_t *len)
{
  struct filebuf *fb;
  ssize_t nread;
  flockfile(stream);
  fb = &fb_pool[fb_pool_cur];
  if (fb->fp != stream && fb->fp != NULL) {
    fb_pool_cur++;
    fb_pool_cur %= FILEBUF_POOL_ITEMS;
    fb = &fb_pool[fb_pool_cur];
  }
  fb->fp = stream;
  nread = getline(&fb->buf, &fb->len, stream);
  funlockfile(stream);
  if (nread == -1) {
    *len = 0;
    return NULL;
  } else {
    *len = (size_t)nread;
    return fb->buf;
  }
}
/*#endif*/

#define fwopen(cookie, fn) funopen(cookie, 0, fn, 0, 0)

struct funopen_cookie {
  void *orig_cookie;
  int (*readfn)(void *cookie, char *buf, int size);
  int (*writefn)(void *cookie, const char *buf, int size);
  off_t (*seekfn)(void *cookie, off_t offset, int whence);
  int (*closefn)(void *cookie);
};

static ssize_t
funopen_read(void *cookie, char *buf, size_t size)
{
  struct funopen_cookie *cookiewrap = cookie;
  if (cookiewrap->readfn == NULL) {
    errno = EBADF;
    return -1;
  }
  return cookiewrap->readfn(cookiewrap->orig_cookie, buf, size);
}

static ssize_t
funopen_write(void *cookie, const char *buf, size_t size)
{
  struct funopen_cookie *cookiewrap = cookie;
  if (cookiewrap->writefn == NULL)
    return EOF;
  return cookiewrap->writefn(cookiewrap->orig_cookie, buf, size);
}

static int
funopen_seek(void *cookie, off64_t *offset, int whence)
{
  struct funopen_cookie *cookiewrap = cookie;
  off_t soff = *offset;
  if (cookiewrap->seekfn == NULL) {
    errno = ESPIPE;
    return -1;
  }
  soff = cookiewrap->seekfn(cookiewrap->orig_cookie, soff, whence);
  *offset = soff;
  return *offset;
}

static int
funopen_close(void *cookie)
{
  struct funopen_cookie *cookiewrap = cookie;
  int rc;
  if (cookiewrap->closefn == NULL)
    return 0;
  rc = cookiewrap->closefn(cookiewrap->orig_cookie);
  free(cookiewrap);
  return rc;
}

static inline __always_inline FILE *
funopen(const void *cookie,
    int (*readfn)(void *cookie, char *buf, int size),
    int (*writefn)(void *cookie, const char *buf, int size),
    off_t (*seekfn)(void *cookie, off_t offset, int whence),
    int (*closefn)(void *cookie))
{
  struct funopen_cookie *cookiewrap;
  cookie_io_functions_t funcswrap = {
  .read = funopen_read,
  .write = funopen_write,
  .seek = funopen_seek,
  .close = funopen_close,
  };
  const char *mode;
  if (readfn) {
    if (writefn == NULL)
      mode = "r";
    else
      mode = "r+";
  } else if (writefn) {
    mode = "w";
  } else {
    errno = EINVAL;
    return NULL;
  }
  cookiewrap = malloc(sizeof(*cookiewrap));
  if (cookiewrap == NULL)
    return NULL;
  cookiewrap->orig_cookie = ____DECONST(void *, cookie);
  cookiewrap->readfn = readfn;
  cookiewrap->writefn = writefn;
  cookiewrap->seekfn = seekfn;
  cookiewrap->closefn = closefn;
  return fopencookie(cookiewrap, mode, funcswrap);
}
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/inlined/stdlib.hi
#ifdef __linux__
#include <sys/cdefs.h>
#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <string.h>

#define srandomdev(...) /* stub for games/phantasia/setup */

static inline __always_inline uint32_t  /* for games/fortune/strfile.nx */
arc4random_uniform(u_int32_t upper_bound)
{
  uint32_t r, min;
  if (upper_bound < 2)
    return 0;
  min = -upper_bound % upper_bound;
  for (;;) {
    r = rand();   /* should be good enough */
    if (r >= min)
      break;
  }
  return (r % upper_bound);
}

#define __ALIGNBYTES  (sizeof(long) - 1)
#define __ALIGNPTR(p) (((unsigned long)(p) + __ALIGNBYTES) & ~__ALIGNBYTES)
#define ALIGN(p) __ALIGNPTR(p)

const char *__progname;

static inline __always_inline const char *
getprogname(void)
{
  if (__progname == NULL)
    __progname = program_invocation_short_name;
  return __progname;
}

static inline __always_inline void
setprogname(const char *progname)
{
  size_t i;
  for (i = strlen(progname); i > 0; i--) {
    if (progname[i - 1] == '/') {
      __progname = progname + i;
      return;
    }
  }
  __progname = progname;
}

#define __INVALID         1
#define __TOOSMALL        2
#define __TOOLARGE        3

static inline __always_inline long long
strtonum(const char *numstr, long long minval, long long maxval,
    const char **errstrp)
{
  long long ll = 0;
  char *ep;
  int error = 0;
  struct errval {
    const char *errstr;
    int err;
  } ev[4] = {
    { NULL,         0 },
    { "invalid",    EINVAL },
    { "too small",  ERANGE },
    { "too large",  ERANGE },
  };
  ev[0].err = errno;
  errno = 0;
  if (minval > maxval)
    error = __INVALID;
  else {
    ll = strtoll(numstr, &ep, 10);
    if (numstr == ep || *ep != '\0')
      error = __INVALID;
    else if ((ll == LLONG_MIN && errno == ERANGE) || ll < minval)
      error = __TOOSMALL;
    else if ((ll == LLONG_MAX && errno == ERANGE) || ll > maxval)
      error = __TOOLARGE;
  }
  if (errstrp != NULL)
    *errstrp = ev[error].errstr;
  errno = ev[error].err;
  if (error)
    ll = 0;
  return (ll);
}

#define __HS_SWAP(a, b, count, size, tmp) { count = size; do { \
        tmp = *a; *a++ = *b; *b++ = tmp; } while (--count); }
#define __HS_COPY(a, b, count, size, tmp1, tmp2) { count = size; tmp1 = a; \
        tmp2 = b; do { *tmp1++ = *tmp2++; } while (--count); }

#define __HS_CREATE(initval, nmemb, par_i, child_i, par, child, size, count, tmp) { \
        for (par_i = initval; (child_i = par_i * 2) <= nmemb; par_i = child_i) { \
                child = base + child_i * size; \
                if (child_i < nmemb && compar(child, child + size) < 0) { \
                        child += size; \
                        ++child_i; \
                } \
                par = base + par_i * size; \
                if (compar(child, par) <= 0) \
                        break; \
                __HS_SWAP(par, child, count, size, tmp); \
        } \
}

#define __HS_SELECT(par_i, child_i, nmemb, par, child, size, k, count, tmp1, tmp2) { \
        for (par_i = 1; (child_i = par_i * 2) <= nmemb; par_i = child_i) { \
                child = base + child_i * size; \
                if (child_i < nmemb && compar(child, child + size) < 0) { \
                        child += size; \
                        ++child_i; \
                } \
                par = base + par_i * size; \
                __HS_COPY(par, child, count, size, tmp1, tmp2); \
        } \
        for (;;) { \
                child_i = par_i; \
                par_i = child_i / 2; \
                child = base + child_i * size; \
                par = base + par_i * size; \
                if (child_i == 1 || compar(k, par) < 0) { \
                        __HS_COPY(child, k, count, size, tmp1, tmp2); \
                        break; \
                } \
                __HS_COPY(child, par, count, size, tmp1, tmp2); \
        } \
}

static inline __always_inline int
heapsort(void *vbase, size_t nmemb, size_t size,
         int (*compar)(const void *, const void *))
{
  size_t cnt, i, j, l;
  char tmp, *tmp1, *tmp2;
  char *base, *k, *p, *t;
  if (nmemb <= 1)
    return (0);
  if (!size) {
    errno = EINVAL;
    return (-1);
  }
  if ((k = malloc(size)) == NULL)
    return (-1);
  base = (char *)vbase - size;
  for (l = nmemb / 2 + 1; --l;)
    __HS_CREATE(l, nmemb, i, j, t, p, size, cnt, tmp);
  while (nmemb > 1) {
    __HS_COPY(k, base + nmemb * size, cnt, size, tmp1, tmp2);
    __HS_COPY(base + nmemb * size, base + size, cnt, size, tmp1, tmp2);
    --nmemb;
    __HS_SELECT(i, j, nmemb, t, p, size, k, cnt, tmp1, tmp2);
  }
  free(k);
  return (0);
}


#define __MS_THRESHOLD 16
#define __MS_ISIZE sizeof(int)
#define __MS_PSIZE sizeof(u_char *)
#define __MS_ICOPY_LIST(src, dst, last) do \
        *(int*)dst = *(int*)src, src += __MS_ISIZE, dst += __MS_ISIZE; \
        while(src < last)
#define __MS_ICOPY_ELT(src, dst, i) do \
        *(int*) dst = *(int*) src, src += __MS_ISIZE, dst += __MS_ISIZE; \
        while (i -= __MS_ISIZE)
#define __MS_CCOPY_LIST(src, dst, last) do *dst++ = *src++; while (src < last)
#define __MS_CCOPY_ELT(src, dst, i) do *dst++ = *src++; while (i -= 1)
#define __MS_rounddown2(x, y) ((x) & ~((y) - 1))
#define __MS_EVAL(p) (u_char **) ((u_char *)0 + \
        (__MS_rounddown2((u_char *)p + __MS_PSIZE - 1 - (u_char *)0, __MS_PSIZE)))

#define __MS_swap(a, b) { s = b; i = size; do { tmp = *a; \
        *a++ = *s; *s++ = tmp; } while (--i); a -= size; }
#define __MS_reverse(bot, top) { s = top; do { i = size; do { tmp = *bot; \
        *bot++ = *s; *s++ = tmp; } while (--i); s -= size2;} while(bot < s);}

static inline __always_inline void
__MS_insertionsort(u_char *a, size_t n, size_t size,
              int (*cmp)(const void *, const void *))
{
  u_char *ai, *s, *t, *u, tmp;
  int i;
  for (ai = a+size; --n >= 1; ai += size)
    for (t = ai; t > a; t -= size) {
      u = t - size;
      if (cmp(u, t) <= 0)
        break;
      __MS_swap(u, t);
    }
}

static inline __always_inline void
__MS_setup(u_char *list1, u_char *list2, size_t n, size_t size,
      int (*cmp)(const void *, const void *))
{
  int i, length, size2, tmp, sense;
  u_char *f1, *f2, *s, *l2, *last, *p2;
  size2 = size*2;
  if (n <= 5) {
    __MS_insertionsort(list1, n, size, cmp);
    *__MS_EVAL(list2) = (u_char*) list2 + n*size;
                return;
  }
  i = 4 + (n & 1);
  __MS_insertionsort(list1 + (n - i) * size, i, size, cmp);
  last = list1 + size * (n - i);
  *__MS_EVAL(list2 + (last - list1)) = list2 + n * size;
  p2 = list2;
  f1 = list1;
  sense = (cmp(f1, f1 + size) > 0);
  for (; f1 < last; sense = !sense) {
    length = 2;
    for (f2 = f1 + size2; f2 < last; f2 += size2) {
      if ((cmp(f2, f2+ size) > 0) != sense)
        break;
      length += 2;
    }
    if (length < __MS_THRESHOLD) {
      do {
        p2 = *__MS_EVAL(p2) = f1 + size2 - list1 + list2;
        if (sense > 0)
          __MS_swap (f1, f1 + size);
      } while ((f1 += size2) < f2);
    } else {
      l2 = f2;
      for (f2 = f1 + size2; f2 < l2; f2 += size2) {
        if ((cmp(f2-size, f2) > 0) != sense) {
          p2 = *__MS_EVAL(p2) = f2 - list1 + list2;
          if (sense > 0)
            __MS_reverse(f1, f2-size);
          f1 = f2;
        }
      }
      if (sense > 0)
        __MS_reverse (f1, f2-size);
      f1 = f2;
      if (f2 < last || cmp(f2 - size, f2) > 0)
        p2 = *__MS_EVAL(p2) = f2 - list1 + list2;
      else
        p2 = *__MS_EVAL(p2) = list2 + n*size;
    }
  }
}


static inline __always_inline int
mergesort(void *base, size_t nmemb, size_t size,
          int (*cmp)(const void *, const void *))
{
  size_t i;
  int sense;
  int big, __iflag;
  u_char *f1, *f2, *t, *b, *tp2, *q, *l1, *l2;
  u_char *list2, *list1, *p2, *p, *last, **p1;
  if (size < __MS_PSIZE / 2) {
    errno = EINVAL;
    return (-1);
  }
  if (nmemb == 0)
    return (0);
  __iflag = 0;
  if (!(size % __MS_ISIZE) && !(((char *)base - (char *)0) % __MS_ISIZE))
    __iflag = 1;
  if ((list2 = malloc(nmemb * size + __MS_PSIZE)) == NULL)
    return (-1);
  list1 = base;
  __MS_setup(list1, list2, nmemb, size, cmp);
  last = list2 + nmemb * size;
  i = big = 0;
  while (*__MS_EVAL(list2) != last) {
    l2 = list1;
    p1 = __MS_EVAL(list1);
    for (tp2 = p2 = list2; p2 != last; p1 = __MS_EVAL(l2)) {
      p2 = *__MS_EVAL(p2);
      f1 = l2;
      f2 = l1 = list1 + (p2 - list2);
      if (p2 != last)
      p2 = *__MS_EVAL(p2);
      l2 = list1 + (p2 - list2);
      while (f1 < l1 && f2 < l2) {
        if ((*cmp)(f1, f2) <= 0) {
          q = f2;
          b = f1, t = l1;
          sense = -1;
        } else {
          q = f1;
          b = f2, t = l2;
          sense = 0;
        }
        if (!big) {
          while ((b += size) < t && cmp(q, b) >sense)
            if (++i == 6) {
              big = 1;
              goto __MS_EXPONENTIAL;
            }
        } else {
__MS_EXPONENTIAL:
          for (i = size; ; i <<= 1)
            if ((p = (b + i)) >= t) {
              if ((p = t - size) > b && (*cmp)(q, p) <= sense)
                t = p;
              else
                b = p;
              break;
            } else if ((*cmp)(q, p) <= sense) {
              t = p;
              if (i == size)
                big = 0;
              goto __MS_FASTCASE;
            } else
              b = p;
          while (t > b+size) {
            i = (((t - b) / size) >> 1) * size;
            if ((*cmp)(q, p = b + i) <= sense)
              t = p;
            else
              b = p;
          }
          goto __MS_COPY;
__MS_FASTCASE:
          while (i > size)
            if ((*cmp)(q, p = b + (i >>= 1)) <= sense)
              t = p;
            else
              b = p;
__MS_COPY:
          b = t;
        }
        i = size;
        if (q == f1) {
          if (__iflag) {
            __MS_ICOPY_LIST(f2, tp2, b);
            __MS_ICOPY_ELT(f1, tp2, i);
          } else {
            __MS_CCOPY_LIST(f2, tp2, b);
            __MS_CCOPY_ELT(f1, tp2, i);
          }
        } else {
          if (__iflag) {
            __MS_ICOPY_LIST(f1, tp2, b);
            __MS_ICOPY_ELT(f2, tp2, i);
          } else {
            __MS_CCOPY_LIST(f1, tp2, b);
            __MS_CCOPY_ELT(f2, tp2, i);
          }
        }
      }
      if (f2 < l2) {
        if (__iflag) {
          __MS_ICOPY_LIST(f2, tp2, l2);
        } else {
          __MS_CCOPY_LIST(f2, tp2, l2);
        }
      } else if (f1 < l1) {
        if (__iflag) {
          __MS_ICOPY_LIST(f1, tp2, l1);
        } else {
          __MS_CCOPY_LIST(f1, tp2, l1);
        }
      }
        *p1 = l2;
    }
    tp2 = list1;
    list1 = list2;
    list2 = tp2;
    last = list2 + nmemb*size;
  }
  if (base == list2) {
    memmove(list2, list1, nmemb*size);
    list2 = list1;
  }
  free(list2);
  return (0);
}
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/inlined/string.hi
#ifdef __linux__
#define QUAD_MIN   LLONG_MIN    /* for usr.bin/expr/expr.y */
#define QUAD_MAX   LLONG_MAX    /* for usr.bin/find/function.c */

static __inline __always_inline size_t
strlcat(char * __restrict dst, const char * __restrict src, size_t siz)
{
  char *d = dst;
  const char *s = src;
  size_t n = siz;
  size_t dlen;
  while (n-- != 0 && *d != '\0')
    d++;
  dlen = d - dst;
  n = siz - dlen;
  if (n == 0)
    return(dlen + strlen(s));
  while (*s != '\0') {
      if (n != 1) {
        *d++ = *s;
        n--;
      }
      s++;
  }
  *d = '\0';
  return(dlen + (s - src));
}

static __inline __always_inline size_t
strlcpy(char *dst, const char *src, size_t siz){
  char *d = dst;
  const char *s = src;
  size_t n = siz;

  if (!dst || !src)
    return 0;
  if (n != 0 && --n != 0) {
    do {
      if ((*d++ = *s++) == 0)
        break;
    } while (--n != 0);
  }
  if (n == 0) {
    if (siz != 0)
      *d = '\0';
    while (*s++) ;
  }
  return(s - src - 1);
}

#include <sys/types.h>
#include <sys/stat.h>

static __inline __always_inline void
strmode(mode_t mode, char *p)
{
  switch (mode & S_IFMT) {
  case S_IFDIR:
    *p++ = 'd';
    break;
  case S_IFCHR:
    *p++ = 'c';
    break;
  case S_IFBLK:
    *p++ = 'b';
    break;
  case S_IFREG:
    *p++ = '-';
    break;
  case S_IFLNK:
    *p++ = 'l';
    break;
  case S_IFSOCK:
    *p++ = 's';
    break;
#ifdef S_IFIFO
  case S_IFIFO:
    *p++ = 'p';
    break;
#endif
#ifdef S_IFWHT
  case S_IFWHT:
    *p++ = 'w';
    break;
#endif
  default:
   *p++ = '?';
    break;
  }
  if (mode & S_IRUSR)
    *p++ = 'r';
  else
    *p++ = '-';
  if (mode & S_IWUSR)
    *p++ = 'w';
  else
    *p++ = '-';
  switch (mode & (S_IXUSR | S_ISUID)) {
  case 0:
    *p++ = '-';
    break;
  case S_IXUSR:
    *p++ = 'x';
    break;
  case S_ISUID:
    *p++ = 'S';
    break;
  case S_IXUSR | S_ISUID:
    *p++ = 's';
    break;
  }
  if (mode & S_IRGRP)
    *p++ = 'r';
  else
    *p++ = '-';
  if (mode & S_IWGRP)
    *p++ = 'w';
  else
   *p++ = '-';
  switch (mode & (S_IXGRP | S_ISGID)) {
  case 0:
    *p++ = '-';
    break;
  case S_IXGRP:
    *p++ = 'x';
    break;
  case S_ISGID:
    *p++ = 'S';
    break;
  case S_IXGRP | S_ISGID:
    *p++ = 's';
    break;
  }
  if (mode & S_IROTH)
    *p++ = 'r';
  else
    *p++ = '-';
  if (mode & S_IWOTH)
    *p++ = 'w';
  else
    *p++ = '-';
  switch (mode & (S_IXOTH | S_ISVTX)) {
  case 0:
    *p++ = '-';
    break;
  case S_IXOTH:
    *p++ = 'x';
    break;
  case S_ISVTX:
    *p++ = 'T';
    break;
  case S_IXOTH | S_ISVTX:
    *p++ = 't';
    break;
  }
  *p++ = ' ';
  *p = '\0';
}
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/inlined/tree.hi
#ifdef __linux__
#include <sys/cdefs.h>
#include <stddef.h>
#include <stdint.h>
struct spinlock {
  int counta;
  int countb;
};
#define RB_SCAN_INFO(name, type) struct name##_scan_info { \
    struct name##_scan_info *link; struct type *node; }
#define RB_HEAD(name, type) struct name { struct type *rbh_root; \
    struct name##_scan_info *rbh_inprog; struct spinlock rbh_spin; }
#define RB_ENTRY(type) \
    struct { struct type *rbe_left; struct type *rbe_right; \
    struct type *rbe_parent; int rbe_color; }
#define RB_PROTOTYPE_STATIC(name, type, field, cmp) \
    _RB_PROTOTYPE(name, type, field, cmp, ____unused static)
#define RB_GENERATE(name, type, field, cmp) \
    _RB_GENERATE(name, type, field, cmp,)

#define _RB_PROTOTYPE(name, type, field, cmp, STORQUAL) \
  STORQUAL void name##_RB_INSERT_COLOR(struct name *, struct type *); \
  STORQUAL void name##_RB_REMOVE_COLOR(struct name *, struct type *, struct type *);\
  STORQUAL struct type *name##_RB_REMOVE(struct name *, struct type *); \
  STORQUAL struct type *name##_RB_INSERT(struct name *, struct type *); \
  STORQUAL struct type *name##_RB_FIND(struct name *, struct type *); \
  STORQUAL int name##_RB_SCAN(struct name *, int (*)(struct type *, void *), \
                              int (*)(struct type *, void *), void *); \
  STORQUAL int name##_RB_SCAN_NOLK(struct name *, int (*)(struct type *, void *),\
                                   int (*)(struct type *, void *), void *); \
  STORQUAL struct type *name##_RB_NEXT(struct type *); \
  STORQUAL struct type *name##_RB_PREV(struct type *); \
  STORQUAL struct type *name##_RB_MINMAX(struct name *, int); \
  RB_SCAN_INFO(name, type)
#define _RB_GENERATE(name, type, field, cmp, STORQUAL) \
  STORQUAL void \
  name##_RB_INSERT_COLOR(struct name *head, struct type *elm) { \
    struct type *parent, *gparent, *tmp; \
    while ((parent = RB_PARENT(elm, field)) != NULL && \
           RB_COLOR(parent, field) == RB_RED) { \
      gparent = RB_PARENT(parent, field); \
      if (parent == RB_LEFT(gparent, field)) { \
        tmp = RB_RIGHT(gparent, field); \
        if (tmp && RB_COLOR(tmp, field) == RB_RED) { \
          RB_COLOR(tmp, field) = RB_BLACK; \
          RB_SET_BLACKRED(parent, gparent, field); \
          elm = gparent; \
          continue; \
        } \
        if (RB_RIGHT(parent, field) == elm) { \
          RB_ROTATE_LEFT(head, parent, tmp, field); \
          tmp = parent; \
          parent = elm; \
          elm = tmp; \
        } \
        RB_SET_BLACKRED(parent, gparent, field); \
        RB_ROTATE_RIGHT(head, gparent, tmp, field); \
      } else { \
        tmp = RB_LEFT(gparent, field); \
        if (tmp && RB_COLOR(tmp, field) == RB_RED) { \
          RB_COLOR(tmp, field) = RB_BLACK; \
          RB_SET_BLACKRED(parent, gparent, field); \
          elm = gparent; \
          continue; \
        } \
        if (RB_LEFT(parent, field) == elm) { \
          RB_ROTATE_RIGHT(head, parent, tmp, field); \
          tmp = parent; \
          parent = elm; \
          elm = tmp; \
        } \
        RB_SET_BLACKRED(parent, gparent, field); \
        RB_ROTATE_LEFT(head, gparent, tmp, field); \
      } \
    } \
    RB_COLOR(head->rbh_root, field) = RB_BLACK; \
  } \
  STORQUAL void \
  name##_RB_REMOVE_COLOR(struct name *head, struct type *parent, \
                         struct type *elm) \
  { \
    struct type *tmp; \
    while ((elm == NULL || RB_COLOR(elm, field) == RB_BLACK) && \
            elm != RB_ROOT(head)) { \
      if (RB_LEFT(parent, field) == elm) { \
        tmp = RB_RIGHT(parent, field); \
        if (RB_COLOR(tmp, field) == RB_RED) { \
          RB_SET_BLACKRED(tmp, parent, field); \
          RB_ROTATE_LEFT(head, parent, tmp, field); \
          tmp = RB_RIGHT(parent, field); \
        } \
        if ((RB_LEFT(tmp, field) == NULL || \
             RB_COLOR(RB_LEFT(tmp, field), field) == RB_BLACK) && \
            (RB_RIGHT(tmp, field) == NULL || \
             RB_COLOR(RB_RIGHT(tmp, field), field) == RB_BLACK)) { \
          RB_COLOR(tmp, field) = RB_RED; \
          elm = parent; \
          parent = RB_PARENT(elm, field); \
        } else { \
          if (RB_RIGHT(tmp, field) == NULL || \
              RB_COLOR(RB_RIGHT(tmp, field), field) == RB_BLACK) { \
            struct type *oleft; \
            if ((oleft = RB_LEFT(tmp, field)) != NULL) \
              RB_COLOR(oleft, field) = RB_BLACK; \
            RB_COLOR(tmp, field) = RB_RED; \
            RB_ROTATE_RIGHT(head, tmp, oleft, field); \
            tmp = RB_RIGHT(parent, field); \
          } \
          RB_COLOR(tmp, field) = RB_COLOR(parent, field); \
          RB_COLOR(parent, field) = RB_BLACK; \
          if (RB_RIGHT(tmp, field)) \
            RB_COLOR(RB_RIGHT(tmp, field), field) = RB_BLACK; \
          RB_ROTATE_LEFT(head, parent, tmp, field); \
          elm = RB_ROOT(head); \
          break; \
        } \
      } else { \
        tmp = RB_LEFT(parent, field); \
        if (RB_COLOR(tmp, field) == RB_RED) { \
          RB_SET_BLACKRED(tmp, parent, field); \
          RB_ROTATE_RIGHT(head, parent, tmp, field); \
          tmp = RB_LEFT(parent, field); \
        } \
        if ((RB_LEFT(tmp, field) == NULL || \
             RB_COLOR(RB_LEFT(tmp, field), field) == RB_BLACK) &&\
            (RB_RIGHT(tmp, field) == NULL || \
             RB_COLOR(RB_RIGHT(tmp, field), field) == RB_BLACK)) { \
          RB_COLOR(tmp, field) = RB_RED; \
          elm = parent; \
          parent = RB_PARENT(elm, field); \
        } else { \
          if (RB_LEFT(tmp, field) == NULL || \
              RB_COLOR(RB_LEFT(tmp, field), field) == RB_BLACK) { \
            struct type *oright; \
            if ((oright = RB_RIGHT(tmp, field)) != NULL) \
              RB_COLOR(oright, field) = RB_BLACK; \
            RB_COLOR(tmp, field) = RB_RED; \
            RB_ROTATE_LEFT(head, tmp, oright, field); \
            tmp = RB_LEFT(parent, field); \
          } \
          RB_COLOR(tmp, field) = RB_COLOR(parent, field); \
          RB_COLOR(parent, field) = RB_BLACK; \
          if (RB_LEFT(tmp, field)) \
            RB_COLOR(RB_LEFT(tmp, field), field) = RB_BLACK; \
          RB_ROTATE_RIGHT(head, parent, tmp, field); \
          elm = RB_ROOT(head); \
          break; \
        } \
      } \
    } \
    if (elm) \
      RB_COLOR(elm, field) = RB_BLACK; \
  } \
  STORQUAL struct type * \
  name##_RB_REMOVE(struct name *head, struct type *elm) \
  { \
    struct type *child, *parent, *old; \
    struct name##_scan_info *inprog; \
    int color; \
    for (inprog = RB_INPROG(head); inprog; inprog = inprog->link) { \
      if (inprog->node == elm) \
        inprog->node = RB_NEXT(name, head, elm); \
    } \
    old = elm; \
    if (RB_LEFT(elm, field) == NULL) \
      child = RB_RIGHT(elm, field); \
    else if (RB_RIGHT(elm, field) == NULL) \
      child = RB_LEFT(elm, field); \
    else { \
      struct type *left; \
      elm = RB_RIGHT(elm, field); \
      while ((left = RB_LEFT(elm, field)) != NULL) \
        elm = left; \
      child = RB_RIGHT(elm, field); \
      parent = RB_PARENT(elm, field); \
      color = RB_COLOR(elm, field); \
      if (child) \
        RB_PARENT(child, field) = parent; \
      if (parent) { \
        if (RB_LEFT(parent, field) == elm) \
          RB_LEFT(parent, field) = child; \
        else \
          RB_RIGHT(parent, field) = child; \
        RB_AUGMENT(parent); \
      } else \
        RB_ROOT(head) = child; \
      if (RB_PARENT(elm, field) == old) \
        parent = elm; \
      (elm)->field = (old)->field; \
      if (RB_PARENT(old, field)) { \
        if (RB_LEFT(RB_PARENT(old, field), field) == old) \
          RB_LEFT(RB_PARENT(old, field), field) = elm; \
        else \
          RB_RIGHT(RB_PARENT(old, field), field) = elm; \
        RB_AUGMENT(RB_PARENT(old, field)); \
      } else \
        RB_ROOT(head) = elm; \
      RB_PARENT(RB_LEFT(old, field), field) = elm; \
      if (RB_RIGHT(old, field)) \
        RB_PARENT(RB_RIGHT(old, field), field) = elm; \
      if (parent) { \
        left = parent; \
        do { \
          RB_AUGMENT(left); \
        } while ((left = RB_PARENT(left, field)) != NULL); \
      } \
      goto color; \
    } \
    parent = RB_PARENT(elm, field); \
    color = RB_COLOR(elm, field); \
    if (child) \
      RB_PARENT(child, field) = parent; \
    if (parent) { \
      if (RB_LEFT(parent, field) == elm) \
        RB_LEFT(parent, field) = child; \
      else \
        RB_RIGHT(parent, field) = child; \
      RB_AUGMENT(parent); \
    } else \
      RB_ROOT(head) = child; \
color: \
    if (color == RB_BLACK) \
      name##_RB_REMOVE_COLOR(head, parent, child); \
    return (old); \
  } \
  STORQUAL struct type * \
  name##_RB_INSERT(struct name *head, struct type *elm) \
  { \
    struct type *tmp; \
    struct type *parent = NULL; \
    int comp = 0; \
    tmp = RB_ROOT(head); \
    while (tmp) { \
      parent = tmp; \
      comp = (cmp)(elm, parent); \
      if (comp < 0) \
        tmp = RB_LEFT(tmp, field); \
      else if (comp > 0) \
        tmp = RB_RIGHT(tmp, field); \
      else \
        return(tmp); \
    } \
    RB_SET(elm, parent, field); \
    if (parent != NULL) { \
      if (comp < 0) \
        RB_LEFT(parent, field) = elm; \
      else \
        RB_RIGHT(parent, field) = elm; \
      RB_AUGMENT(parent); \
    } else \
      RB_ROOT(head) = elm; \
    name##_RB_INSERT_COLOR(head, elm); \
    return (NULL); \
  } \
  STORQUAL struct type * \
  name##_RB_FIND(struct name *head, struct type *elm) \
  { \
    struct type *tmp = RB_ROOT(head); \
    int comp; \
    while (tmp) { \
      comp = cmp(elm, tmp); \
      if (comp < 0) \
        tmp = RB_LEFT(tmp, field); \
      else if (comp > 0) \
        tmp = RB_RIGHT(tmp, field); \
      else \
        return (tmp); \
      } \
    return (NULL); \
  } \
  static int \
  name##_SCANCMP_ALL(struct type *type ____unused, void *data ____unused) \
  { \
    return(0); \
  } \
  static inline void \
  name##_scan_info_link(struct name##_scan_info *scan, struct name *head) \
  { \
    RB_SCAN_LOCK(&head->rbh_spin); \
    scan->link = RB_INPROG(head); \
    RB_INPROG(head) = scan; \
    RB_SCAN_UNLOCK(&head->rbh_spin); \
  } \
  static inline void \
  name##_scan_info_done(struct name##_scan_info *scan, struct name *head) \
  { \
    struct name##_scan_info **infopp; \
    RB_SCAN_LOCK(&head->rbh_spin); \
    infopp = &RB_INPROG(head); \
    while (*infopp != scan) \
      infopp = &(*infopp)->link; \
    *infopp = scan->link; \
    RB_SCAN_UNLOCK(&head->rbh_spin); \
  } \
  static inline int \
  _##name##_RB_SCAN(struct name *head, int (*scancmp)(struct type *, void *), \
             int (*callback)(struct type *, void *), void *data, int uselock) \
  { \
    struct name##_scan_info info; \
    struct type *best; \
    struct type *tmp; \
    int count; \
    int comp; \
    if (scancmp == NULL) \
      scancmp = name##_SCANCMP_ALL; \
    tmp = RB_ROOT(head); \
    best = NULL; \
    while (tmp) { \
      comp = scancmp(tmp, data); \
      if (comp < 0) { \
        tmp = RB_RIGHT(tmp, field); \
      } else if (comp > 0) { \
        tmp = RB_LEFT(tmp, field); \
      } else { \
        best = tmp; \
        if (RB_LEFT(tmp, field) == NULL) \
          break; \
        tmp = RB_LEFT(tmp, field); \
      } \
    } \
    count = 0; \
    if (best) { \
      info.node = RB_NEXT(name, head, best); \
      if (uselock) \
        name##_scan_info_link(&info, head); \
      while ((comp = callback(best, data)) >= 0) { \
        count += comp; \
        best = info.node; \
        if (best == NULL || scancmp(best, data) != 0) \
          break; \
        info.node = RB_NEXT(name, head, best); \
      } \
      if (uselock) \
        name##_scan_info_done(&info, head); \
      if (comp < 0) \
        count = comp; \
    } \
    return(count); \
  } \
  STORQUAL int \
  name##_RB_SCAN(struct name *head, int (*scancmp)(struct type *, void *), \
                 int (*callback)(struct type *, void *), void *data) \
  { \
    return _##name##_RB_SCAN(head, scancmp, callback, data, 1); \
  } \
  STORQUAL int \
  name##_RB_SCAN_NOLK(struct name *head, int (*scancmp)(struct type *, void *), \
                      int (*callback)(struct type *, void *), void *data) \
  { \
    return _##name##_RB_SCAN(head, scancmp, callback, data, 0); \
  } \
  STORQUAL struct type * \
  name##_RB_NEXT(struct type *elm)\
  { \
    if (RB_RIGHT(elm, field)) { \
      elm = RB_RIGHT(elm, field); \
      while (RB_LEFT(elm, field)) \
        elm = RB_LEFT(elm, field); \
    } else { \
      if (RB_PARENT(elm, field) && \
          (elm == RB_LEFT(RB_PARENT(elm, field), field))) \
        elm = RB_PARENT(elm, field); \
      else { \
        while (RB_PARENT(elm, field) && \
               (elm == RB_RIGHT(RB_PARENT(elm, field), field))) \
          elm = RB_PARENT(elm, field); \
          elm = RB_PARENT(elm, field); \
      } \
    } \
    return (elm); \
  } \
  STORQUAL struct type * \
  name##_RB_PREV(struct type *elm) \
  { \
    if (RB_LEFT(elm, field)) { \
      elm = RB_LEFT(elm, field); \
      while (RB_RIGHT(elm, field)) \
        elm = RB_RIGHT(elm, field); \
    } else { \
      if (RB_PARENT(elm, field) && \
          (elm == RB_RIGHT(RB_PARENT(elm, field), field))) \
        elm = RB_PARENT(elm, field); \
      else { \
        while (RB_PARENT(elm, field) && \
               (elm == RB_LEFT(RB_PARENT(elm, field), field)))\
          elm = RB_PARENT(elm, field); \
        elm = RB_PARENT(elm, field); \
      } \
    } \
    return (elm); \
  } \
  STORQUAL struct type * \
  name##_RB_MINMAX(struct name *head, int val) \
  { \
    struct type *tmp = RB_ROOT(head); \
    struct type *parent = NULL; \
    while (tmp) { \
      parent = tmp; \
      if (val < 0) \
        tmp = RB_LEFT(tmp, field); \
      else \
        tmp = RB_RIGHT(tmp, field); \
    } \
    return (parent); \
  }


#define RB_INIT(root) do { \
   (root)->rbh_root = NULL; (root)->rbh_inprog = NULL; } while (/*CONSTCOND*/ 0)

#define RB_SCAN_LOCK(spin)
#define RB_SCAN_UNLOCK(spin)

#define RB_BLACK        0
#define RB_RED          1
#define RB_LEFT(elm, field)             (elm)->field.rbe_left
#define RB_RIGHT(elm, field)            (elm)->field.rbe_right
#define RB_PARENT(elm, field)           (elm)->field.rbe_parent
#define RB_COLOR(elm, field)            (elm)->field.rbe_color
#define RB_ROOT(head)                   (head)->rbh_root
#define RB_INPROG(head)                 (head)->rbh_inprog

#define RB_SET(elm, parent, field) do { \
    RB_PARENT(elm, field) = parent; \
    RB_LEFT(elm, field) = RB_RIGHT(elm, field) = NULL; \
    RB_COLOR(elm, field) = RB_RED; \
  } while (/*CONSTCOND*/ 0)

#define RB_SET_BLACKRED(black, red, field) do { \
    RB_COLOR(black, field) = RB_BLACK; \
    RB_COLOR(red, field) = RB_RED; \
  } while (/*CONSTCOND*/ 0)

#ifndef RB_AUGMENT
#define RB_AUGMENT(x)   do {} while (0)
#endif

#define RB_ROTATE_LEFT(head, elm, tmp, field) do { \
  (tmp) = RB_RIGHT(elm, field); \
  if ((RB_RIGHT(elm, field) = RB_LEFT(tmp, field)) != NULL) { \
    RB_PARENT(RB_LEFT(tmp, field), field) = (elm); \
  } \
  RB_AUGMENT(elm); \
  if ((RB_PARENT(tmp, field) = RB_PARENT(elm, field)) != NULL) { \
    if ((elm) == RB_LEFT(RB_PARENT(elm, field), field)) \
      RB_LEFT(RB_PARENT(elm, field), field) = (tmp); \
    else \
      RB_RIGHT(RB_PARENT(elm, field), field) = (tmp); \
  } else \
    (head)->rbh_root = (tmp); \
  RB_LEFT(tmp, field) = (elm); \
  RB_PARENT(elm, field) = (tmp); \
  RB_AUGMENT(tmp); \
  if ((RB_PARENT(tmp, field))) \
    RB_AUGMENT(RB_PARENT(tmp, field)); \
} while (/*CONSTCOND*/ 0)

#define RB_ROTATE_RIGHT(head, elm, tmp, field) do { \
  (tmp) = RB_LEFT(elm, field); \
  if ((RB_LEFT(elm, field) = RB_RIGHT(tmp, field)) != NULL) { \
     RB_PARENT(RB_RIGHT(tmp, field), field) = (elm); \
  } \
  RB_AUGMENT(elm); \
  if ((RB_PARENT(tmp, field) = RB_PARENT(elm, field)) != NULL) { \
    if ((elm) == RB_LEFT(RB_PARENT(elm, field), field)) \
      RB_LEFT(RB_PARENT(elm, field), field) = (tmp); \
    else \
      RB_RIGHT(RB_PARENT(elm, field), field) = (tmp); \
    } else \
      (head)->rbh_root = (tmp); \
    RB_RIGHT(tmp, field) = (elm); \
    RB_PARENT(elm, field) = (tmp); \
    RB_AUGMENT(tmp); \
    if ((RB_PARENT(tmp, field))) \
       RB_AUGMENT(RB_PARENT(tmp, field)); \
} while (/*CONSTCOND*/ 0)

#define RB_NEGINF       -1

#define RB_INSERT(name, root, elm)      name##_RB_INSERT(root, elm)
#define RB_REMOVE(name, root, elm)      name##_RB_REMOVE(root, elm)
#define RB_FIND(name, root, elm)        name##_RB_FIND(root, elm)

#define RB_NEXT(name, root, elm)        name##_RB_NEXT(elm)

#define RB_MIN(name, root)              name##_RB_MINMAX(root, RB_NEGINF)

#define RB_FOREACH(x, name, head) \
    for ((x) = RB_MIN(name, head); (x) != NULL; (x) = name##_RB_NEXT(x))

#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/inlined/unistd.hi
#ifdef __linux__
#include <sys/cdefs.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <ctype.h>
#include <signal.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#define SET_LEN 6
#define SET_LEN_INCR 4

#ifndef NELEM
#define NELEM(ary) (sizeof(ary) / sizeof((ary)[0]))
#endif

#ifndef SSIZE_MAX  /* bin/dd #include_next <limits.h> issue */
#define SSIZE_MAX LONG_MAX
#endif

#if !defined(S_ISTXT) && defined(S_ISVTX)
#define S_ISTXT S_ISVTX
#endif

#ifndef MAXBSIZE
#define MAXBSIZE      65536
#endif

#ifndef st_atimespec
#define st_atimespec st_atim
#define st_mtimespec st_mtim
#define st_ctimespec st_ctim
#endif

static inline __always_inline int
undelete(const char *path)
{
  if (path == NULL || 1)
    return -1;
}

int optreset;

static __inline __always_inline int
bsd_getopt(int argc, char * const argv[], const char *shortopts)
{
  char *fakeopts = NULL;
  int ch;
  if (optreset == 1) {
    optreset = 0;
    optind = 0;
  }
  setenv("POSIXLY_CORRECT", "yes", 0);  /* fix bsd find, "find foo -type f" */
  if (strchr(shortopts, '-') == NULL)
    return getopt(argc, argv, shortopts);
  /* else try to recover for "-iblah" by converting to "blah-" */
  if (shortopts[0] == '-') {
    size_t len;
    unsigned int i;
    len = strlen(shortopts);
    fakeopts = __builtin_alloca(len+1);
    for (i = 1; i < len; i++)
      fakeopts[i-1] = shortopts[i];
    fakeopts[len-1] = '-';
    fakeopts[len] = '\0';
    ch = getopt(argc, argv, fakeopts);
  } else
    ch = getopt(argc, argv, shortopts);
  if (ch == -1 && optind < argc && strcmp(argv[optind], "-") == 0) {
    optind++;
    return '-';  /* aka fix "env -" */
  }
  return ch;
}

#ifndef _GL_GETOPT_H /* do not use in libgreputils */
#define getopt(argc, argv, opts) bsd_getopt((argc), (argv), (opts))
#endif

typedef struct bitcmd {
  char    cmd;
  char    cmd2;
  mode_t  bits;
} BITCMD;

#define CMD2_CLR        0x01
#define CMD2_SET        0x02
#define CMD2_GBITS      0x04
#define CMD2_OBITS      0x08
#define CMD2_UBITS      0x10

static inline __always_inline mode_t
getmode(const void *bbox, mode_t omode)
{
  const BITCMD *set;
  mode_t clrval, newmode, value;
  set = (const BITCMD *)bbox;
  newmode = omode;
  for (value = 0;; set++)
    switch(set->cmd) {
    case 'u':
      value = (newmode & S_IRWXU) >> 6;
      goto common_getmode;
    case 'g':
      value = (newmode & S_IRWXG) >> 3;
      goto common_getmode;
    case 'o':
      value = newmode & S_IRWXO;
common_getmode:
      if (set->cmd2 & CMD2_CLR) {
        clrval = (set->cmd2 & CMD2_SET) ?  S_IRWXO : value;
        if (set->cmd2 & CMD2_UBITS)
          newmode &= ~((clrval<<6) & set->bits);
        if (set->cmd2 & CMD2_GBITS)
          newmode &= ~((clrval<<3) & set->bits);
        if (set->cmd2 & CMD2_OBITS)
          newmode &= ~(clrval & set->bits);
      }
      if (set->cmd2 & CMD2_SET) {
        if (set->cmd2 & CMD2_UBITS)
          newmode |= (value<<6) & set->bits;
        if (set->cmd2 & CMD2_GBITS)
          newmode |= (value<<3) & set->bits;
        if (set->cmd2 & CMD2_OBITS)
          newmode |= value & set->bits;
      }
      break;
    case '+':
      newmode |= set->bits;
      break;
    case '-':
      newmode &= ~set->bits;
      break;
    case 'X':
      if (omode & (S_IFDIR|S_IXUSR|S_IXGRP|S_IXOTH))
        newmode |= set->bits;
      break;
    case '\0':
    default:
      return (newmode);
  }
}

#define ADDCMD(a, b, c, d) \
  if (set >= endset) { \
    BITCMD *newset; \
    setlen += SET_LEN_INCR; \
    newset = realloc(saveset, sizeof(BITCMD) * setlen); \
    if (!newset) { \
      if (saveset) \
        free(saveset); \
      saveset = NULL; \
      return (NULL); \
    } \
    set = newset + (set - saveset); \
    saveset = newset; \
    endset = newset + (setlen - 2); \
  } \
  set = addcmd(set, (a), (b), (c), (d))

#define STANDARD_BITS   (S_ISUID|S_ISGID|S_IRWXU|S_IRWXG|S_IRWXO)

static inline __always_inline BITCMD *
addcmd(BITCMD *set, int op, int who, int oparg, u_int mask)
{
  switch (op) {
  case '=':
    set->cmd = '-';
    set->bits = who ? who : STANDARD_BITS;
    set++;
    op = '+';
    /* FALLTHROUGH */
  case '+':
  case '-':
  case 'X':
    set->cmd = op;
    set->bits = (who ? (unsigned)who : mask) & oparg;
    break;
  case 'u':
  case 'g':
  case 'o':
    set->cmd = op;
    if (who) {
      set->cmd2 = ((who & S_IRUSR) ? CMD2_UBITS : 0) |
                  ((who & S_IRGRP) ? CMD2_GBITS : 0) |
                  ((who & S_IROTH) ? CMD2_OBITS : 0);
      set->bits = (mode_t)~0;
    } else {
      set->cmd2 = CMD2_UBITS | CMD2_GBITS | CMD2_OBITS;
      set->bits = mask;
    }
    if (oparg == '+')
      set->cmd2 |= CMD2_SET;
    else if (oparg == '-')
      set->cmd2 |= CMD2_CLR;
    else if (oparg == '=')
      set->cmd2 |= CMD2_SET|CMD2_CLR;
    break;
  }
  return (set + 1);
}
static void
compress_mode(BITCMD *set)
{
  BITCMD *nset;
  int setbits, clrbits, Xbits, op;
  for (nset = set;;) {
    while ((op = nset->cmd) != '+' && op != '-' && op != 'X') {
      *set++ = *nset++;
      if (!op)
        return;
    }
    for (setbits = clrbits = Xbits = 0;; nset++) {
      if ((op = nset->cmd) == '-') {
        clrbits |= nset->bits;
        setbits &= ~nset->bits;
        Xbits &= ~nset->bits;
      } else if (op == '+') {
        setbits |= nset->bits;
        clrbits &= ~nset->bits;
        Xbits &= ~nset->bits;
      } else if (op == 'X')
        Xbits |= nset->bits & ~setbits;
      else
        break;
    }
    if (clrbits) {
      set->cmd = '-';
      set->cmd2 = 0;
      set->bits = clrbits;
      set++;
    }
    if (setbits) {
      set->cmd = '+';
      set->cmd2 = 0;
      set->bits = setbits;
      set++;
    }
    if (Xbits) {
      set->cmd = 'X';
      set->cmd2 = 0;
      set->bits = Xbits;
      set++;
    }
  }
}

static inline __always_inline void *
setmode(const char *p)
{
  int perm, who;
  char op, *ep;
  BITCMD *set, *saveset, *endset;
  sigset_t sigset, sigoset;
  mode_t mask;
  int equalopdone=0, permXbits, setlen;
  long perml;
  if (!*p)
    return (NULL);
  sigfillset(&sigset);
  sigprocmask(SIG_BLOCK, &sigset, &sigoset);
  umask(mask = umask(0));
  mask = ~mask;
  sigprocmask(SIG_SETMASK, &sigoset, NULL);
  setlen = SET_LEN + 2;
  if ((set = malloc((u_int)(sizeof(BITCMD) * setlen))) == NULL)
    return (NULL);
  saveset = set;
  endset = set + (setlen - 2);
  if (isdigit((unsigned char)*p)) {
    perml = strtol(p, &ep, 8);
    if (*ep || perml < 0 || perml & ~(STANDARD_BITS|S_ISTXT)) {
      free(saveset);
      return (NULL);
    }
    perm = (mode_t)perml;
    ADDCMD('=', (STANDARD_BITS|S_ISTXT), perm, mask);
    set->cmd = 0;
    return (saveset);
  }
  for (;;) {
    for (who = 0;; ++p) {
      switch (*p) {
      case 'a':
        who |= STANDARD_BITS;
        break;
      case 'u':
        who |= S_ISUID|S_IRWXU;
        break;
      case 'g':
        who |= S_ISGID|S_IRWXG;
        break;
      case 'o':
        who |= S_IRWXO;
        break;
      default:
        goto getop;
      }
    }
getop:
    if ((op = *p++) != '+' && op != '-' && op != '=') {
      free(saveset);
      return (NULL);
    }
    if (op == '=')
      equalopdone = 0;
    who &= ~S_ISTXT;
    for (perm = 0, permXbits = 0;; ++p) {
      switch (*p) {
      case 'r':
        perm |= S_IRUSR|S_IRGRP|S_IROTH;
        break;
      case 's':
        if (!who || who & ~S_IRWXO)
          perm |= S_ISUID|S_ISGID;
        break;
      case 't':
        if (!who || who & ~S_IRWXO) {
          who |= S_ISTXT;
          perm |= S_ISTXT;
        }
        break;
      case 'w':
        perm |= S_IWUSR|S_IWGRP|S_IWOTH;
        break;
      case 'X':
        permXbits = S_IXUSR|S_IXGRP|S_IXOTH;
        break;
      case 'x':
        perm |= S_IXUSR|S_IXGRP|S_IXOTH;
        break;
      case 'u':
      case 'g':
      case 'o':
        if (perm) {
          ADDCMD(op, who, perm, mask);
          perm = 0;
        }
        if (op == '=')
          equalopdone = 1;
        if (op == '+' && permXbits) {
          ADDCMD('X', who, permXbits, mask);
          permXbits = 0;
        }
        ADDCMD(*p, who, op, mask);
        break;
      default:
        if (perm || (op == '=' && !equalopdone)) {
          if (op == '=')
            equalopdone = 1;
          ADDCMD(op, who, perm, mask);
          perm = 0;
        }
        if (permXbits) {
          ADDCMD('X', who, permXbits, mask);
          permXbits = 0;
        }
        goto apply_setmode;
      }
    }
apply_setmode:
    if (!*p)
      break;
    if (*p != ',')
      goto getop;
    ++p;
  }
  set->cmd = 0;
  compress_mode(saveset);
  return (saveset);
}

#undef ADDCMD
#undef STANDARD_BITS
#undef SET_LEN
#undef SET_LEN_INCR
#undef CMD2_CLR
#undef CMD2_SET
#undef CMD2_GBITS
#undef CMD2_OBITS
#undef CMD2_UBITS
#endif
EOF

cat << 'EOF' > /tmp/dfly/cross/compat/vis_portable.h
#include <sys/cdefs.h>
#include <sys/types.h>
#include <ctype.h>
#include <errno.h>
#include <limits.h>  /* for MB_LEN_MAX */
#include <stdint.h>
#include <string.h>
#include <wchar.h>
#include <wctype.h>

#define VIS_OCTAL       0x0001
#define VIS_CSTYLE      0x0002
#define VIS_SP          0x0004
#define VIS_TAB         0x0008
#define VIS_NL          0x0010
#define VIS_WHITE       (VIS_SP | VIS_TAB | VIS_NL)
#define VIS_SAFE        0x0020
#define VIS_DQ          0x8000
#define VIS_ALL         0x00010000
#define VIS_NOSLASH     0x0040
#define VIS_HTTP1808    0x0080
#define VIS_HTTPSTYLE   0x0080
#define VIS_MIMESTYLE   0x0100
#define VIS_HTTP1866    0x0200
#define VIS_NOESCAPE    0x0400
#define _VIS_END        0x0800
#define VIS_GLOB        0x1000
#define VIS_SHELL       0x2000
#define VIS_META        (VIS_WHITE | VIS_GLOB | VIS_SHELL)
#define VIS_NOLOCALE    0x4000
#define UNVIS_VALID      1
#define UNVIS_VALIDPUSH  2
#define UNVIS_NOCHAR     3
#define UNVIS_SYNBAD    -1
#define UNVIS_ERROR     -2
#define UNVIS_END       _VIS_END

#define S_GROUND        0
#define S_START         1
#define S_META          2
#define S_META1         3
#define S_CTRL          4
#define S_OCTAL2        5
#define S_OCTAL3        6
#define S_HEX           7
#define S_HEX1          8
#define S_HEX2          9
#define S_MIME1         10
#define S_MIME2         11
#define S_EATCRNL       12
#define S_AMP           13
#define S_NUMBER        14
#define S_STRING        15

#define __arraycount(__x)       (sizeof(__x) / sizeof(__x[0]))
#define isoctal(c) (((unsigned char)(c)) >= '0' && \
                    ((unsigned char)(c)) <= '7')
#define xtod(c)    (isdigit(c) ? (c - '0') : ((tolower(c) - 'a') + 10))
#define XTOD(c)    (isdigit(c) ? (c - '0') : ((c - 'A') + 10))

static const struct nv_unvis {
        char name[7];
        uint8_t value;
} nv_unvis[] = {
  { "AElig",      198 },  { "Aacute",     193 },
  { "Acirc",      194 },  { "Agrave",     192 },
  { "Aring",      197 },  { "Atilde",     195 },
  { "Auml",       196 },  { "Ccedil",     199 },
  { "ETH",        208 },  { "Eacute",     201 },
  { "Ecirc",      202 },  { "Egrave",     200 },
  { "Euml",       203 },  { "Iacute",     205 },
  { "Icirc",      206 },  { "Igrave",     204 },
  { "Iuml",       207 },  { "Ntilde",     209 },
  { "Oacute",     211 },  { "Ocirc",      212 },
  { "Ograve",     210 },  { "Oslash",     216 },
  { "Otilde",     213 },  { "Ouml",       214 },
  { "THORN",      222 },  { "Uacute",     218 },
  { "Ucirc",      219 },  { "Ugrave",     217 },
  { "Uuml",       220 },  { "Yacute",     221 },
  { "aacute",     225 },  { "acirc",      226 },
  { "acute",      180 },  { "aelig",      230 },
  { "agrave",     224 },  { "amp",         38 },
  { "aring",      229 },  { "atilde",     227 },
  { "auml",       228 },  { "brvbar",     166 },
  { "ccedil",     231 },  { "cedil",      184 },
  { "cent",       162 },  { "copy",       169 },
  { "curren",     164 },  { "deg",        176 },
  { "divide",     247 },  { "eacute",     233 },
  { "ecirc",      234 },  { "egrave",     232 },
  { "eth",        240 },  { "euml",       235 },
  { "frac12",     189 },  { "frac14",     188 },
  { "frac34",     190 },  { "gt",          62 },
  { "iacute",     237 },  { "icirc",      238 },
  { "iexcl",      161 },  { "igrave",     236 },
  { "iquest",     191 },  { "iuml",       239 },
  { "laquo",      171 },  { "lt",          60 },
  { "macr",       175 },  { "micro",      181 },
  { "middot",     183 },  { "nbsp",       160 },
  { "not",        172 },  { "ntilde",     241 },
  { "oacute",     243 },  { "ocirc",      244 },
  { "ograve",     242 },  { "ordf",       170 },
  { "ordm",       186 },  { "oslash",     248 },
  { "otilde",     245 },  { "ouml",       246 },
  { "para",       182 },  { "plusmn",     177 },
  { "pound",      163 },  { "quot",        34 },
  { "raquo",      187 },  { "reg",        174 },
  { "sect",       167 },  { "shy",        173 },
  { "sup1",       185 },  { "sup2",       178 },
  { "sup3",       179 },  { "szlig",      223 },
  { "thorn",      254 },  { "times",      215 },
  { "uacute",     250 },  { "ucirc",      251 },
  { "ugrave",     249 },  { "uml",        168 },
  { "uuml",       252 },  { "yacute",     253 },
  { "yen",        165 },  { "yuml",       255 },
};

static inline __always_inline int
unvis(char *cp, int c, int *astate, int flag)
{
  unsigned char uc = (unsigned char)c;
  unsigned char st, ia, is, lc;

#define GS(a)           ((a) & 0xff)
#define SS(a, b)        (((uint32_t)(a) << 24) | (b))
#define GI(a)           ((uint32_t)(a) >> 24)

  st = GS(*astate);
  if (flag & UNVIS_END) {
    switch (st) {
    case S_OCTAL2:
    case S_OCTAL3:
    case S_HEX2:
      *astate = SS(0, S_GROUND);
      return UNVIS_VALID;
    case S_GROUND:
      return UNVIS_NOCHAR;
    default:
      return UNVIS_SYNBAD;
    }
  }
  switch (st) {
  case S_GROUND:
    *cp = 0;
    if ((flag & VIS_NOESCAPE) == 0 && c == '\\') {
      *astate = SS(0, S_START);
      return UNVIS_NOCHAR;
    }
    if ((flag & VIS_HTTP1808) && c == '%') {
      *astate = SS(0, S_HEX1);
      return UNVIS_NOCHAR;
    }
    if ((flag & VIS_HTTP1866) && c == '&') {
      *astate = SS(0, S_AMP);
      return UNVIS_NOCHAR;
    }
    if ((flag & VIS_MIMESTYLE) && c == '=') {
      *astate = SS(0, S_MIME1);
      return UNVIS_NOCHAR;
    }
    *cp = c;
    return UNVIS_VALID;
    case S_START:
    switch(c) {
    case '-':
      *cp = 0;
      *astate = SS(0, S_GROUND);
      return UNVIS_NOCHAR;
    case '\\':
      *cp = c;
      *astate = SS(0, S_GROUND);
      return UNVIS_VALID;
    case '0': case '1': case '2': case '3':
    case '4': case '5': case '6': case '7':
      *cp = (c - '0');
      *astate = SS(0, S_OCTAL2);
      return UNVIS_NOCHAR;
    case 'M':
      *cp = (char)0200;
      *astate = SS(0, S_META);
      return UNVIS_NOCHAR;
    case '^':
      *astate = SS(0, S_CTRL);
      return UNVIS_NOCHAR;
    case 'n':
      *cp = '\n';
      *astate = SS(0, S_GROUND);
      return UNVIS_VALID;
    case 'r':
      *cp = '\r';
      *astate = SS(0, S_GROUND);
      return UNVIS_VALID;
    case 'b':
      *cp = '\b';
      *astate = SS(0, S_GROUND);
      return UNVIS_VALID;
    case 'a':
      *cp = '\007';
      *astate = SS(0, S_GROUND);
      return UNVIS_VALID;
    case 'v':
      *cp = '\v';
      *astate = SS(0, S_GROUND);
      return UNVIS_VALID;
    case 't':
      *cp = '\t';
      *astate = SS(0, S_GROUND);
      return UNVIS_VALID;
    case 'f':
      *cp = '\f';
      *astate = SS(0, S_GROUND);
      return UNVIS_VALID;
    case 's':
      *cp = ' ';
      *astate = SS(0, S_GROUND);
      return UNVIS_VALID;
    case 'E':
      *cp = '\033';
      *astate = SS(0, S_GROUND);
      return UNVIS_VALID;
    case 'x':
      *astate = SS(0, S_HEX);
      return UNVIS_NOCHAR;
    case '\n':
      *astate = SS(0, S_GROUND);
      return UNVIS_NOCHAR;
    case '$':
      *astate = SS(0, S_GROUND);
      return UNVIS_NOCHAR;
    default:
      if (isgraph(c)) {
        *cp = c;
        *astate = SS(0, S_GROUND);
        return UNVIS_VALID;
      }
    }
  goto badunvis;
  case S_META:
    if (c == '-')
      *astate = SS(0, S_META1);
    else if (c == '^')
      *astate = SS(0, S_CTRL);
    else
      goto badunvis;
    return UNVIS_NOCHAR;
  case S_META1:
    *astate = SS(0, S_GROUND);
    *cp |= c;
    return UNVIS_VALID;
  case S_CTRL:
    if (c == '?')
      *cp |= 0177;
    else
      *cp |= c & 037;
    *astate = SS(0, S_GROUND);
    return UNVIS_VALID;
  case S_OCTAL2:
    if (isoctal(uc)) {
      *cp = (*cp << 3) + (c - '0');
      *astate = SS(0, S_OCTAL3);
      return UNVIS_NOCHAR;
    }
    *astate = SS(0, S_GROUND);
    return UNVIS_VALIDPUSH;
  case S_OCTAL3:
    *astate = SS(0, S_GROUND);
    if (isoctal(uc)) {
      *cp = (*cp << 3) + (c - '0');
      return UNVIS_VALID;
    }
    return UNVIS_VALIDPUSH;
  case S_HEX:
    if (!isxdigit(uc))
      goto badunvis;
    /* FALLTHROUGH */
  case S_HEX1:
    if (isxdigit(uc)) {
      *cp = xtod(uc);
      *astate = SS(0, S_HEX2);
      return UNVIS_NOCHAR;
    }
    *astate = SS(0, S_GROUND);
    return UNVIS_VALIDPUSH;
  case S_HEX2:
    *astate = S_GROUND;
    if (isxdigit(uc)) {
      *cp = xtod(uc) | (*cp << 4);
      return UNVIS_VALID;
    }
    return UNVIS_VALIDPUSH;
  case S_MIME1:
    if (uc == '\n' || uc == '\r') {
      *astate = SS(0, S_EATCRNL);
      return UNVIS_NOCHAR;
    }
    if (isxdigit(uc) && (isdigit(uc) || isupper(uc))) {
      *cp = XTOD(uc);
      *astate = SS(0, S_MIME2);
      return UNVIS_NOCHAR;
    }
    goto badunvis;
  case S_MIME2:
    if (isxdigit(uc) && (isdigit(uc) || isupper(uc))) {
      *astate = SS(0, S_GROUND);
      *cp = XTOD(uc) | (*cp << 4);
      return UNVIS_VALID;
    }
    goto badunvis;
  case S_EATCRNL:
    switch (uc) {
    case '\r':
    case '\n':
      return UNVIS_NOCHAR;
    case '=':
      *astate = SS(0, S_MIME1);
      return UNVIS_NOCHAR;
    default:
      *cp = uc;
      *astate = SS(0, S_GROUND);
      return UNVIS_VALID;
    }
  case S_AMP:
    *cp = 0;
    if (uc == '#') {
      *astate = SS(0, S_NUMBER);
      return UNVIS_NOCHAR;
    }
    *astate = SS(0, S_STRING);
    /* FALLTHROUGH */
  case S_STRING:
    ia = *cp;
    is = GI(*astate);
    lc = is == 0 ? 0 : nv_unvis[ia].name[is - 1];
    if (uc == ';')
    uc = '\0';
    for (; ia < __arraycount(nv_unvis); ia++) {
      if (is != 0 && nv_unvis[ia].name[is - 1] != lc)
        goto badunvis;
      if (nv_unvis[ia].name[is] == uc)
        break;
    }
    if (ia == __arraycount(nv_unvis))
      goto badunvis;
    if (uc != 0) {
      *cp = ia;
      *astate = SS(is + 1, S_STRING);
      return UNVIS_NOCHAR;
    }
    *cp = nv_unvis[ia].value;
    *astate = SS(0, S_GROUND);
    return UNVIS_VALID;
  case S_NUMBER:
    if (uc == ';')
      return UNVIS_VALID;
    if (!isdigit(uc))
      goto badunvis;
    *cp += (*cp * 10) + uc - '0';
    return UNVIS_NOCHAR;
  default:
  badunvis:
    *astate = SS(0, S_GROUND);
    return UNVIS_SYNBAD;
  }
#undef GS
#undef SS
#undef GI
}
#undef __arraycount
#undef isoctal
#undef xtod
#undef XTOD

static inline __always_inline int
strnunvisx(char *dst, size_t dlen, const char *src, int flag)
{
  char c;
  char t = '\0', *start = dst;
  int state = 0;

#define CHECKSPACE() \
  do { \
    if (dlen-- == 0) { \
      errno = ENOSPC; \
        return -1; \
    } \
  } while (/*CONSTCOND*/0)

  while ((c = *src++) != '\0') {
 again:
    switch (unvis(&t, c, &state, flag)) {
    case UNVIS_VALID:
      CHECKSPACE();
      *dst++ = t;
      break;
    case UNVIS_VALIDPUSH:
      CHECKSPACE();
      *dst++ = t;
      goto again;
    case 0:
      case UNVIS_NOCHAR:
      break;
    case UNVIS_SYNBAD:
      errno = EINVAL;
      return -1;
    default:
      errno = EINVAL;
      return -1;
    }
  }
  if (unvis(&t, c, &state, UNVIS_END) == UNVIS_VALID) {
    CHECKSPACE();
    *dst++ = t;
  }
  CHECKSPACE();
  *dst = '\0';
  return (int)(dst - start);
#undef CHECKSPACE
}

static inline __always_inline int
strunvis(char *dst, const char *src)
{
  return strnunvisx(dst, (size_t)~0, src, 0);
}

#define MAXEXTRAS       30
static const wchar_t char_shell_vis[] = L"'`\";&<>()|{}]\\$!^~";
static const wchar_t char_glob_vis[] = L"*?[#";

static inline __always_inline wchar_t *
makeextralist(int flags, const char *src)
{
  wchar_t *dst, *d;
  size_t len;
  const wchar_t *s;
  mbstate_t mbstate;
  bzero(&mbstate, sizeof(mbstate));
  len = strlen(src);
  if ((dst = calloc(len + MAXEXTRAS, sizeof(*dst))) == NULL)
    return NULL;
  if ((flags & VIS_NOLOCALE) || mbsrtowcs(dst, &src, len, &mbstate) == (size_t)-1) {
    size_t i;
    for (i = 0; i < len; i++)
      dst[i] = (wchar_t)(u_char)src[i];
    d = dst + len;
  } else
    d = dst + wcslen(dst);
  if (flags & VIS_GLOB)
    for (s = char_glob_vis; *s; *d++ = *s++)
      continue;
  if (flags & VIS_SHELL)
    for (s = char_shell_vis; *s; *d++ = *s++)
      continue;
  if (flags & VIS_SP) *d++ = L' ';
  if (flags & VIS_TAB) *d++ = L'\t';
  if (flags & VIS_NL) *d++ = L'\n';
  if (flags & VIS_DQ) *d++ = L'"';
  if ((flags & VIS_NOSLASH) == 0) *d++ = L'\\';
  *d = L'\0';
  return dst;
}
#undef MAXEXTRAS

#define iscgraph(c)     isgraph(c)
#undef BELL
#define BELL L'\a'
#define ISGRAPH(flags, c) \
    (((flags) & VIS_NOLOCALE) ? iscgraph(c) : iswgraph(c))
#define iswoctal(c)     (((u_char)(c)) >= L'0' && ((u_char)(c)) <= L'7')
#define iswwhite(c)     (c == L' ' || c == L'\t' || c == L'\n')
#define iswsafe(c)      (c == L'\b' || c == BELL || c == L'\r')
#define xtoa(c)         L"0123456789abcdef"[c]
#define XTOA(c)         L"0123456789ABCDEF"[c]

static wchar_t *
do_mbyte(wchar_t *dst, wint_t c, int flags, wint_t nextc, int iswextra)
{
  if (flags & VIS_CSTYLE) {
    switch (c) {
    case L'\n':
      *dst++ = L'\\'; *dst++ = L'n';
      return dst;
    case L'\r':
      *dst++ = L'\\'; *dst++ = L'r';
      return dst;
    case L'\b':
      *dst++ = L'\\'; *dst++ = L'b';
      return dst;
    case BELL:
      *dst++ = L'\\'; *dst++ = L'a';
      return dst;
    case L'\v':
      *dst++ = L'\\'; *dst++ = L'v';
      return dst;
    case L'\t':
      *dst++ = L'\\'; *dst++ = L't';
      return dst;
    case L'\f':
      *dst++ = L'\\'; *dst++ = L'f';
      return dst;
    case L' ':
      *dst++ = L'\\'; *dst++ = L's';
      return dst;
    case L'\0':
      *dst++ = L'\\'; *dst++ = L'0';
      if (iswoctal(nextc)) {
        *dst++ = L'0';
        *dst++ = L'0';
      }
      return dst;
    case L'n':
    case L'r':
    case L'b':
    case L'a':
    case L'v':
    case L't':
    case L'f':
    case L's':
    case L'x':
    case L'0':
    case L'E':
    case L'F':
    case L'M':
    case L'-':
    case L'^':
    case L'$': /* vis(1) -l */
      break;
    default:
      if (ISGRAPH(flags, c) && !iswoctal(c)) {
        *dst++ = L'\\';
        *dst++ = c;
        return dst;
      }
    }
  }
  if (iswextra || ((c & 0177) == L' ') || (flags & VIS_OCTAL)) {
    *dst++ = L'\\';
    *dst++ = (u_char)(((u_int32_t)(u_char)c >> 6) & 03) + L'0';
    *dst++ = (u_char)(((u_int32_t)(u_char)c >> 3) & 07) + L'0';
    *dst++ =                             (c       & 07) + L'0';
  } else {
    if ((flags & VIS_NOSLASH) == 0)
      *dst++ = L'\\';
    if (c & 0200) {
      c &= 0177;
      *dst++ = L'M';
    }
    if (iswcntrl(c)) {
      *dst++ = L'^';
      if (c == 0177)
        *dst++ = L'?';
      else
        *dst++ = c + L'@';
      } else {
        *dst++ = L'-';
        *dst++ = c;
      }
  }
  return dst;
}

static inline __always_inline wchar_t *
do_svis(wchar_t *dst, wint_t c, int flags, wint_t nextc, const wchar_t *extra)
{
  int iswextra, i, shft;
  uint64_t bmsk, wmsk;
  iswextra = wcschr(extra, c) != NULL;
  if (((flags & VIS_ALL) == 0) && !iswextra &&
      (ISGRAPH(flags, c) || iswwhite(c) ||
      ((flags & VIS_SAFE) && iswsafe(c)))) {
    *dst++ = c;
    return dst;
  }
  wmsk = 0;
  for (i = sizeof(wmsk) - 1; i >= 0; i--) {
    shft = i * NBBY;
    bmsk = (uint64_t)0xffLL << shft;
    wmsk |= bmsk;
    if ((c & wmsk) || i == 0)
      dst = do_mbyte(dst, (wint_t)(
      (uint64_t)(c & bmsk) >> shft),
      flags, nextc, iswextra);
    }
  return dst;
}

static inline __always_inline wchar_t *
do_hvis(wchar_t *dst, wint_t c, int flags, wint_t nextc, const wchar_t *extra)
{
  if (iswalnum(c)
      || c == L'$' || c == L'-' || c == L'_' || c == L'.' || c == L'+'
      || c == L'!' || c == L'*' || c == L'\'' || c == L'(' || c == L')'
      || c == L',')
    dst = do_svis(dst, c, flags, nextc, extra);
  else {
    *dst++ = L'%';
    *dst++ = xtoa(((unsigned int)c >> 4) & 0xf);
    *dst++ = xtoa((unsigned int)c & 0xf);
  }
  return dst;
}

static inline __always_inline wchar_t *
do_mvis(wchar_t *dst, wint_t c, int flags, wint_t nextc, const wchar_t *extra)
{
  if ((c != L'\n') &&
      ((iswspace(c) && (nextc == L'\r' || nextc == L'\n')) ||
      (!iswspace(c) && (c < 33 || (c > 60 && c < 62) || c > 126)) ||
    wcschr(L"#$@[\\]^`{|}~", c) != NULL)) {
    *dst++ = L'=';
    *dst++ = XTOA(((unsigned int)c >> 4) & 0xf);
    *dst++ = XTOA((unsigned int)c & 0xf);
  } else
    dst = do_svis(dst, c, flags, nextc, extra);
  return dst;
}

typedef wchar_t *(*visfun_t)(wchar_t *, wint_t, int, wint_t, const wchar_t *);

static inline __always_inline visfun_t
getvisfun(int flags)
{
  if (flags & VIS_HTTPSTYLE)
    return do_hvis;
  if (flags & VIS_MIMESTYLE)
    return do_mvis;
  return do_svis;
}


static inline __always_inline int
istrsenvisx(char **mbdstp, size_t *dlen, const char *mbsrc, size_t mblength,
    int flags, const char *mbextra, int *cerr_ptr)
{
  wchar_t *dst, *src, *pdst, *psrc, *start, *extra;
  size_t len, olen;
  uint64_t bmsk, wmsk;
  wint_t c;
  visfun_t f;
  int clen = 0, cerr, error = -1, i, shft;
  char *mbdst, *mdst;
  ssize_t mbslength, maxolen;
  mbstate_t mbstate;
  mbslength = (ssize_t)mblength;
  if (mbslength == 1)
    mbslength++;

  psrc = pdst = extra = NULL;
  mdst = NULL;
  if ((psrc = calloc(mbslength + 1, sizeof(*psrc))) == NULL)
    return -1;
  if ((pdst = calloc((16 * mbslength) + 1, sizeof(*pdst))) == NULL)
    goto outistrsenvisx;
  if (*mbdstp == NULL) {
    if ((mdst = calloc((16 * mbslength) + 1, sizeof(*mdst))) == NULL)
      goto outistrsenvisx;
    *mbdstp = mdst;
  }
  mbdst = *mbdstp;
  dst = pdst;
  src = psrc;
  if (flags & VIS_NOLOCALE) {
    cerr = 1;
  } else {
    cerr = cerr_ptr ? *cerr_ptr : 0;
  }
  bzero(&mbstate, sizeof(mbstate));
  while (mbslength > 0) {
    if (!cerr)
      clen = mbrtowc(src, mbsrc, MB_LEN_MAX, &mbstate);
    if (cerr || clen < 0) {
      *src = (wint_t)(u_char)*mbsrc;
      clen = 1;
      cerr = 1;
    }
    if (clen == 0) {
      clen = 1;
    }
    src++;
    mbsrc += clen;
    mbslength -= clen;
  }
  len = src - psrc;
  src = psrc;
  if (mblength < len)
    len = mblength;
  extra = makeextralist(flags, mbextra);
  if (!extra) {
    if (dlen && *dlen == 0) {
      errno = ENOSPC;
      goto outistrsenvisx;
    }
    *mbdst = '\0';
    error = 0;
    goto outistrsenvisx;
  }
  f = getvisfun(flags);
  for (start = dst; len > 0; len--) {
    c = *src++;
    dst = (*f)(dst, c, flags, len >= 1 ? *src : L'\0', extra);
    if (dst == NULL) {
      errno = ENOSPC;
      goto outistrsenvisx;
    }
  }
  *dst = L'\0';
  len = wcslen(start);
  maxolen = dlen ? *dlen : (wcslen(start) * MB_LEN_MAX + 1);
  olen = 0;
  bzero(&mbstate, sizeof(mbstate));
  for (dst = start; len > 0; len--) {
    if (!cerr)
      clen = wcrtomb(mbdst, *dst, &mbstate);
    if (cerr || clen < 0) {
      clen = 0;
      wmsk = 0;
      for (i = sizeof(wmsk) - 1; i >= 0; i--) {
        shft = i * NBBY;
        bmsk = (uint64_t)0xffLL << shft;
        wmsk |= bmsk;
        if ((*dst & wmsk) || i == 0)
          mbdst[clen++] = (char)(
          (uint64_t)(*dst & bmsk) >> shft);
        }
        cerr = 1;
    }
    if (olen + clen > (size_t)maxolen)
      break;
    mbdst += clen;
    dst++;
    olen += clen;
  }
  *mbdst = '\0';
  if (flags & VIS_NOLOCALE) {
    if (cerr_ptr)
      *cerr_ptr = cerr;
  }
  free(extra);
  free(pdst);
  free(psrc);
  return (int)olen;
outistrsenvisx:
  free(extra);
  free(pdst);
  free(psrc);
  free(mdst);
  return error;
}
#undef iscgraph
#undef BELL
#undef ISGRAPH
#undef iswoctal
#undef iswwhite
#undef iswsafe
#undef xtoa
#undef XTOA

static inline __always_inline int
istrsenvisxl(char **mbdstp, size_t *dlen, const char *mbsrc,
    int flags, const char *mbextra, int *cerr_ptr)
{
  return istrsenvisx(mbdstp, dlen, mbsrc,
      mbsrc != NULL ? strlen(mbsrc) : 0, flags, mbextra, cerr_ptr);
}

static inline __always_inline int
strsvis(char *mbdst, const char *mbsrc, int flags, const char *mbextra)
{
  return istrsenvisxl(&mbdst, NULL, mbsrc, flags, mbextra, NULL);
}
EOF
}

bootstrap_bmake () {
echo "Bootstrapping bmake"
BFLAGS="-DHAVE_CONFIG_H -DNO_PWD_OVERRIDE -DUSE_EMALLOC"
BFLAGS="${BFLAGS} -I$P/usr.bin/bmake"
BFLAGS="${BFLAGS} ${CROSSCFLAGS}"
BFLAGS="${BFLAGS} -D_PATH_DEFSYSPATH=\"$P/share/mk\""
BFLAGS="${BFLAGS} -D__unused"
BFLAGS="${BFLAGS} -DCCVER=\"x99\" -DDFVER=\"999999\" -DOSREL=\"9.9\""
b="arch buf compat cond dir for hash job main make meta metachar"
b="$b parse str strlist suff targ trace var util"
BSRCS=
for i in ${b} ; do
BSRCS="${BSRCS} $P/contrib/bmake/$i.c"
done
cc ${BFLAGS} ${BSRCS} $P/contrib/bmake/lst.lib/*.c -o /tmp/dfly/cross/make
}

bootstrap_cat () {
echo "Bootstrapping cat"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/bin/cat/cat.c -o /tmp/dfly/cross/cat
}

bootstrap_chmod () {
echo "Bootstrapping chmod"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/bin/chmod/chmod.c -o /tmp/dfly/cross/chmod
}

bootstrap_cp () {
echo "Bootstrapping cp"
BFLAGS="${CROSSCFLAGS}"
b="cp utils"
BSRCS=
for i in ${b} ; do
BSRCS="${BSRCS} $P/bin/cp/$i.c"
done
cc ${BFLAGS} ${BSRCS} -o /tmp/dfly/cross/cp
}

bootstrap_env () {
echo "Bootstrapping env"
BFLAGS="${CROSSCFLAGS}"
b="env envopts"
BSRCS=
for i in ${b} ; do
BSRCS="${BSRCS} $P/usr.bin/env/$i.c"
done
cc ${BFLAGS} ${BSRCS} -o /tmp/dfly/cross/env
}

bootstrap_install () {
echo "Bootstrapping install"
BFLAGS="${CROSSCFLAGS} -DBOOTSTRAPPING"
cc ${BFLAGS} $P/usr.bin/xinstall/xinstall.c -o /tmp/dfly/cross/install
}

bootstrap_sync () { # dubious use in installworld
echo "Bootstrapping sync"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/bin/sync/sync.c -o /tmp/dfly/cross/sync
}

bootstrap_time () {
echo "Bootstrapping time"
BFLAGS="${CROSSCFLAGS}"
BFLAGS="${BFLAGS} -DBOOTSTRAPPING"
cc ${BFLAGS} $P/usr.bin/time/time.c -o /tmp/dfly/cross/time
}

bootstrap_uniq () {
echo "Bootstrapping uniq"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/usr.bin/uniq/uniq.c -o /tmp/dfly/cross/uniq
}

bootstrap_xargs () {
echo "Bootstrapping xargs"
BFLAGS="${CROSSCFLAGS}"
BFLAGS="${BFLAGS} -DBOOTSTRAPPING"
b="xargs strnsubst"
BSRCS=
for i in ${b} ; do
BSRCS="${BSRCS} $P/usr.bin/xargs/$i.c"
done
cc ${BFLAGS} ${BSRCS} -o /tmp/dfly/cross/xargs
}

bootstrap_wc () {
echo "Bootstrapping wc"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/usr.bin/wc/wc.c -o /tmp/dfly/cross/wc
}

bootstrap_ln () {
echo "Bootstrapping ln"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/bin/ln/ln.c -o /tmp/dfly/cross/ln
}

bootstrap_mv () {
echo "Bootstrapping mv"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/bin/mv/mv.c -o /tmp/dfly/cross/mv
}

bootstrap_rm () {
echo "Bootstrapping rm"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/bin/rm/rm.c -o /tmp/dfly/cross/rm
}

bootstrap_printf () {
echo "Bootstrapping printf"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/usr.bin/printf/printf.c -o /tmp/dfly/cross/printf
}

bootstrap_touch () {
echo "Bootstrapping touch"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/usr.bin/touch/touch.c -o /tmp/dfly/cross/touch
}

bootstrap_mkdir () {
echo "Bootstrapping mkdir"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/bin/mkdir/mkdir.c -o /tmp/dfly/cross/mkdir
}

bootstrap_mtree () {
echo "Bootstrapping mtree"
BFLAGS="${CROSSCFLAGS}"
BFLAGS="${BFLAGS} -DNO_MD5 -DNO_SHA -DNO_RMD160 -DBOOTSTRAPPING"
b="create compare crc excludes misc mtree"
b="$b only pack_dev spec specspec stat_flags verify"
BSRCS=
for i in ${b} ; do
BSRCS="${BSRCS} $P/usr.sbin/mtree/$i.c"
done
cc ${BFLAGS} ${BSRCS} -o /tmp/dfly/cross/mtree
}

bootstrap_sed () {
echo "Bootstrapping sed"
BFLAGS="${CROSSCFLAGS}"
b="compile main misc process"
BSRCS=
for i in ${b} ; do
BSRCS="${BSRCS} $P/usr.bin/sed/$i.c"
done
cc ${BFLAGS} ${BSRCS} -o /tmp/dfly/cross/sed
}

bootstrap_tr () {
echo "Bootstrapping tr"
BFLAGS="${CROSSCFLAGS}"
b="cmap cset str tr"
BSRCS=
for i in ${b} ; do
BSRCS="${BSRCS} $P/usr.bin/tr/$i.c"
done
cc ${BFLAGS} ${BSRCS} -o /tmp/dfly/cross/tr
}

bootstrap_yacc () {
echo "Bootstrapping yacc"
BFLAGS="${CROSSCFLAGS}"
BFLAGS="${BFLAGS} -DHAVE_FCNTL_H -DHAVE_MKSTEMP -DHAVE_VSNPRINTF"
BFLAGS="${BFLAGS} -DMAXTABLE=65000"
b="closure error graph lalr lr0 main mkpar mstring"
b="$b output reader symtab verbose warshall yaccpar"
BSRCS=
for i in ${b} ; do
BSRCS="${BSRCS} $P/contrib/byacc/$i.c"
done
cc ${BFLAGS} ${BSRCS} -o /tmp/dfly/cross/yacc
}

bootstrap_lex () {
echo "Bootstrapping lex"
BFLAGS="${CROSSCFLAGS}"
BFLAGS="${BFLAGS} -DHAVE_CONFIG_H -I$P/usr.bin/flex -I$P/contrib/flex"
b="ccl dfa ecs scanflags gen main misc nfa parse scan sym tblcmp"
b="$b yylex options scanopt buf tables tables_shared filter regex"
BSRCS=
for i in ${b} ; do
BSRCS="${BSRCS} $P/contrib/flex/src/$i.c"
done
BSRCS="${BSRCS} /tmp/dfly/skel.c"
/tmp/dfly/cross/sed -e 's/m4_/m4postproc_/g' -e 's/m4preproc_/m4_/g' \
  $P/contrib/flex/src/flex.skl | \
  sed -e 's/FLEX_MAJOR_VERSION$/2/g' -e 's/FLEX_MINOR_VERSION$/5/g' \
      -e 's/FLEX_SUBMINOR_VERSION$/37/g' -e 's/m4_changecom//g' \
      -e "s/M4_GEN_PREFIX(\`\(.*\)')/m4postproc_define(yy[[\1]],\
          [[M4_YY_PREFIX[[\1]]m4postproc_ifelse(\$#,0,,[[(\$@)]])]])/g" |\
  sed -e "/m4_include(\`flexint.h/r $P/contrib/flex/src/flexint.h" \
      -e "/m4_include(\`tables_shared.h/r $P/contrib/flex/src/tables_shared.h" \
      -e "/m4_include(\`tables_shared.c/r $P/contrib/flex/src/tables_shared.c" \
      -e '/m4_include(/d' -e '/m4_define(`M4_GEN_PREFIX/,+1d' | \
  sed -e 's/m4postproc_/m4_/g' > /tmp/dfly/skel.c
cc ${BFLAGS} ${BSRCS} -lm -o /tmp/dfly/cross/lex
rm -f /tmp/dfly/skel.c
}

bootstrap_mktemp () {
echo "Bootstrapping mktemp"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/usr.bin/mktemp/mktemp.c -o /tmp/dfly/cross/mktemp
}

bootstrap_join () {
echo "Bootstrapping join"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/usr.bin/join/join.c -o /tmp/dfly/cross/join
}

bootstrap_find () {
echo "Bootstrapping find"
BFLAGS="${CROSSCFLAGS}"
BFLAGS="${BFLAGS} -DBOOTSTRAPPING"
b="find function ls main misc operator option"
BSRCS=
for i in ${b} ; do
BSRCS="${BSRCS} $P/usr.bin/find/$i.c"
done
cc ${BFLAGS} ${BSRCS} -o /tmp/dfly/cross/find
}

bootstrap_sort () {
echo "Bootstrapping sort"
BFLAGS="${CROSSCFLAGS}"
BFLAGS="${BFLAGS} -DWITHOUT_NLS"
b="bwstring coll file mem radixsort sort vsort"
BSRCS=
for i in ${b} ; do
BSRCS="${BSRCS} $P/usr.bin/sort/$i.c"
done
cc ${BFLAGS} ${BSRCS} -o /tmp/dfly/cross/sort
}

bootstrap_tsort () {
echo "Bootstrapping tsort"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/usr.bin/tsort/tsort.c -o /tmp/dfly/cross/tsort
}

bootstrap_lorder () {
echo "Bootstrapping lorder"
cp $P/usr.bin/lorder/lorder.sh /tmp/dfly/cross/lorder
chmod +x /tmp/dfly/cross/lorder
}

bootstrap_m4 () {
echo "Bootstrapping m4"
BFLAGS="${CROSSCFLAGS}"
BFLAGS="${BFLAGS} -DEXTENDED -I$P/usr.bin/m4 -I$P/usr.bin/m4/lib"
b="eval expr look main misc gnum4 trace manual_tokenizer"
BSRCS=
for i in ${b} ; do
BSRCS="${BSRCS} $P/usr.bin/m4/$i.c"
done
cc ${BFLAGS} ${BSRCS} -o /tmp/dfly/cross/m4
}

bootstrap_stat () {
echo "Bootstrapping stat"
BFLAGS="${CROSSCFLAGS}"
BFLAGS="${BFLAGS} -DBOOTSTRAPPING"
cc ${BFLAGS} $P/usr.bin/stat/stat.c -o /tmp/dfly/cross/stat
}

bootstrap_cap_mkdb () {
echo "Bootstrapping cap_mkdb"
BFLAGS="${CROSSCFLAGS}"
cc ${BFLAGS} $P/usr.bin/cap_mkdb/cap_mkdb.c -o /tmp/dfly/cross/cap_mkdb
}

bootstrap_pwd_mkdb () {
echo "Bootstrapping pwd_mkdb"
BFLAGS="${CROSSCFLAGS}"
BFLAGS="${BFLAGS} -DPWD_MKDB_CROSS -I$P/lib/libc/gen"
BSRCS="$P/usr.sbin/pwd_mkdb/pwd_mkdb.c $P/lib/libc/gen/pw_scan.c"
cc ${BFLAGS} ${BSRCS} -o /tmp/dfly/cross/pwd_mkdb
}

bootstrap_libs () {
cp -f /tmp/dfly/obj/$P/btools_x86_64/usr/lib/libl.a /tmp/dfly/cross/lib/
cp -f /tmp/dfly/obj/$P/btools_x86_64/usr/lib/liby.a /tmp/dfly/cross/lib/
cp -f /tmp/dfly/obj/$P/btools_x86_64/usr/lib/libz.a /tmp/dfly/cross/lib/
cp -f /tmp/dfly/obj/$P/btools_x86_64/usr/include/zconf.h /tmp/dfly/cross/simple/
cp -f /tmp/dfly/obj/$P/btools_x86_64/usr/include/zlib.h /tmp/dfly/cross/simple/
}

fake_libutil () {
system=`uname -s`

case ${system} in
  DragonFly*)
    ;;
  *BSD*)
    ;;
  *)
    CROSS_LIBDL=-ldl
    echo "int __dummy_libutil = 0;" > /tmp/dfly/dummy.c
    cc -c /tmp/dfly/dummy.c -o /tmp/dfly/dummy.o
    ar rcs /tmp/dfly/cross/lib/libutil.a /tmp/dfly/dummy.o
    rm -f /tmp/dfly/dummy.c /tmp/dfly/dummy.o
    ;;
esac
}

fake_awk () {
cat << 'EOF' > /tmp/dfly/cross/awk
#!/bin/sh
echo "9999999"
EOF
chmod +x /tmp/dfly/cross/awk
}

fake_date () {
if [ -e /bin/date ]; then
cat << 'EOF' > /tmp/dfly/cross/date
#!/bin/sh
LC_ALL=C /bin/date
EOF
fi
chmod +x /tmp/dfly/cross/date
}

fake_chflags () {
cat << EOF > /tmp/dfly/cross/chflags
#!/bin/sh
EOF
chmod +x /tmp/dfly/cross/chflags
}

fake_hostname () {
if ! type "hostname"  > /dev/null; then
host=crosshost
else
host=${HOSTNAME:-`hostname`}
fi
cat << EOF > /tmp/dfly/cross/hostname
#!/bin/sh
echo "${host}"
EOF
chmod +x /tmp/dfly/cross/hostname
}

fake_sysctl () {
cat << 'EOF' > /tmp/dfly/cross/sysctl
#!/bin/sh
nflag=1
for arg in $@
  do case "$arg" in
    -n)
      nflag=0
      shift ;;
    hw.ncpu)
      [ $nflag -eq 0 ] || echo -n "$arg: "
      echo ${MAKE_JOBS:-`getconf NPROCESSORS_ONLN 2>/dev/null || \
                         getconf _NPROCESSORS_ONLN`}
      shift ;;
    hw.machine_arch)
      [ $nflag -eq 0 ] || echo -n "$arg: "
      echo "x86_64"
      shift ;;
    hw.machine)
      [ $nflag -eq 0 ] || echo -n "$arg: "
      echo "x86_64"
      shift ;;
    hw.platform)
      [ $nflag -eq 0 ] || echo -n "$arg: "
      echo "pc64"
      shift ;;
    hw.pagesize)
      [ $nflag -eq 0 ] || echo -n "$arg: "
      echo "4096"
      shift ;;
    kern.hostname)
      [ $nflag -eq 0 ] || echo -n "$arg: "
      echo `hostname`
      shift ;;
    *)
      echo "fake_sysctl: unhandled $@" >&2
      echo "fake_sysctl: unhandled $@" >> /tmp/dfly/sysctl.log
      exit 1
      break ;;
  esac
done
EOF
chmod +x /tmp/dfly/cross/sysctl
}

fake_uname () {
if ! type "uname"  > /dev/null; then
unamea=crosssystem
else
unamea=${UNAME:-`uname -a`}
fi
if ! type "hostname"  > /dev/null; then
host=crosshost
else
host=${HOSTNAME:-`hostname`}
fi
cat << EOF > /tmp/dfly/cross/uname
#!/bin/sh
if [ \$# -eq 0 ]
then
echo "DragonFly"
exit 0
fi

case "\$1" in
  -a)
    echo "${unamea}"
    ;;
  -i)
    echo "X8_64_CROSS"
    ;;
  -m)
    echo "x86_64"
    ;;
  -n)
    echo "${host}"
    ;;
  -p)
    echo "x86_64"
    ;;
  -r)
    echo "9.9-DEVELOPMENT"
    ;;
  -s)
    echo "DragonFly-cross"
    ;;
  -v)
    echo "${unamea}"
    ;;
  *)
    exit 1
    ;;
esac
EOF
chmod +x /tmp/dfly/cross/uname
}

fake_mkdep () {
cat << 'EOF' > /tmp/dfly/cross/mkdep
#!/bin/sh
D=.depend
append=0
pflag=
while :
  do case "$1" in
    -a)
      shift ;;
    -f)
      D=$2
      shift; shift ;;
    -p)
      shift ;;
    *)
      break ;;
  esac
done
touch $D
EOF
chmod +x /tmp/dfly/cross/mkdep
}

fake_awk2 () {
cp -f /tmp/dfly/obj/$P/btools_x86_64/usr/bin/awk /tmp/dfly/cross/awk
}

fake_cpdup2 () {
cp -f /tmp/dfly/obj/$P/btools_x86_64/bin/cpdup /tmp/dfly/cross/cpdup
}

fake_date2 () {
cp -f /tmp/dfly/cross/date /tmp/dfly/obj/$P/btools_x86_64/usr/bin/date
}

fake_dd2 () {
cp -f /tmp/dfly/obj/$P/btools_x86_64/bin/dd /tmp/dfly/cross/dd
}

fake_chflags2 () {
cp -f /tmp/dfly/cross/chflags /tmp/dfly/obj/$P/btools_x86_64/usr/bin/
}

fake_pwd_mkdb2 () {
cp -f /tmp/dfly/cross/pwd_mkdb /tmp/dfly/obj/$P/btools_x86_64/usr/sbin/
}

fake_hostname2 () {
cp -f /tmp/dfly/cross/hostname /tmp/dfly/obj/$P/btools_x86_64/usr/bin/
}

fake_uname2 () {
cp -f /tmp/dfly/cross/uname /tmp/dfly/obj/$P/btools_x86_64/usr/bin/
}

fake_mkdep2 () {
mv /tmp/dfly/obj/$P/btools_x86_64/usr/bin/mkdep \
   /tmp/dfly/obj/$P/btools_x86_64/usr/bin/mkdep.orig
cp -f /tmp/dfly/cross/mkdep /tmp/dfly/obj/$P/btools_x86_64/usr/bin/
cp /tmp/dfly/obj/$P/btools_x86_64/usr/bin/mkdep.orig /tmp/dfly/cross/mkdep.orig
}

fake_pw3 () {
cat << EOF > /tmp/dfly/cross/pw
#!/bin/sh
EOF
/tmp/dfly/cross/chmod +x /tmp/dfly/cross/pw
}

fake_makedb3 () {
cat << EOF > /tmp/dfly/cross/makedb
#!/bin/sh
EOF
/tmp/dfly/cross/chmod +x /tmp/dfly/cross/makedb
}

build_btools () {
  BSTRAPDIRS1=`cd $P && /tmp/dfly/cross/make -f Makefile.inc1 \
    MACHINE=x86_64 MACHINE_ARCH=x86_64 MACHINE_PLATFORM=pc64 \
    HOST_BINUTILSVER="${PHOSTbinutils}" \
    -V BSTRAPDIRS1:N*hostname`
  BSTRAPDIRS1="lib/liby usr.bin/flex/lib lib/libz usr.bin/printf ${BSTRAPDIRS1}"
  BSTRAPDIRS2=`cd $P && /tmp/dfly/cross/make -f Makefile.inc1 \
    MACHINE=x86_64 MACHINE_ARCH=x86_64 MACHINE_PLATFORM=pc64 \
    HOST_BINUTILSVER="${PHOSTbinutils}" \
    -V BSTRAPDIRS2:N*uname:N*chflags:N*pwd_mkdb`
  echo "B1 is ${BSTRAPDIRS1}"
  echo "B2 is ${BSTRAPDIRS2}"
  cd $P && \
  ${TIMECMD} /tmp/dfly/cross/make _worldtmp _bootstrap-tools _obj _build-tools \
  BSTRAPDIRS1="${BSTRAPDIRS1}" BSTRAPDIRS2="${BSTRAPDIRS2}" \
  _HOSTPATH="${PATH}" MAKEOBJDIRPREFIX="/tmp/dfly/obj" \
  MACHINE="x86_64" MACHINE_ARCH="x86_64" MACHINE_PLATFORM="pc64" \
  HOST_BINUTILSVER="${PHOSTbinutils}" -DNO_WERROR \
  WORLD_CFLAGS="${BCFLAGS} ${CROSSCFLAGS}" \
  > /tmp/dfly/btools.log 2>&1 || (echo "  error: see btools.log" && exit 2)
  [ ! -f ${TIMELOG:-/blah} ] || /tmp/dfly/cross/cat ${TIMELOG}
}

build_ctools () {
  cd $P && \
  ${TIMECMD} /tmp/dfly/cross/make -j${MJ} _cross-tools \
  _HOSTPATH="${PATH}" MAKEOBJDIRPREFIX="/tmp/dfly/obj" \
  MACHINE="x86_64" MACHINE_ARCH="x86_64" MACHINE_PLATFORM="pc64" \
  HOST_BINUTILSVER="${PHOSTbinutils}" CROSS_LIBDL="${CROSS_LIBDL}" \
  -DNO_WERROR -DNO_ALTBINUTILS -DNO_ALTCOMPILER -DNO_PROFILE \
  WORLD_CFLAGS="-I/tmp/dfly/cross/simple ${BCFLAGS} -L/tmp/dfly/cross/lib" \
  > /tmp/dfly/ctools.log 2>&1 || (echo "  error: see ctools.log" && exit 3)
  [ ! -f ${TIMELOG:-/blah} ] || /tmp/dfly/cross/cat ${TIMELOG}
}

build_world () {
  cd $P && \
  ${TIMECMD} /tmp/dfly/cross/make -j${MJ} quickworld \
  _HOSTPATH="/tmp/dfly/cross" MAKEOBJDIRPREFIX="/tmp/dfly/obj" \
  CROSS_CFLAGS="-I/tmp/dfly/cross/simple ${BCFLAGS} -L/tmp/dfly/cross/lib" \
  MACHINE="x86_64" MACHINE_ARCH="x86_64" MACHINE_PLATFORM="pc64" \
  HOST_BINUTILSVER="${PHOSTbinutils}" \
  -DNO_ALTBINUTILS -DNO_ALTCOMPILER -DNOPROFILE -DWANT_INSTALLER -DNO_INITRD \
  > /tmp/dfly/world.log 2>&1 || (echo "  error: see world.log" && exit 4)
  [ ! -f ${TIMELOG:-/blah} ] || /tmp/dfly/cross/cat ${TIMELOG}
}

build_kernel () {
  cd $P && \
  ${TIMECMD} /tmp/dfly/cross/make -j${MJ} buildkernel \
  _HOSTPATH="/tmp/dfly/cross" MAKEOBJDIRPREFIX="/tmp/dfly/obj" \
  HOST_BINUTILSVER="${PHOSTbinutils}" \
  MACHINE="x86_64" MACHINE_ARCH="x86_64" MACHINE_PLATFORM="pc64" \
  -DNO_ALTBINUTILS -DNO_ALTCOMPILER -DNOPROFILE \
  > /tmp/dfly/kernel.log 2>&1 || (echo "  error: see kernel.log" && exit 5)
  [ ! -f ${TIMELOG:-/blah} ] || /tmp/dfly/cross/cat ${TIMELOG}
}

build_world_notc () {
  cd $P && \
  ${TIMECMD} /tmp/dfly/cross/make -j${MJ} quickworld \
  _HOSTPATH="/tmp/dfly/cross" MAKEOBJDIRPREFIX="/tmp/dfly/obj" \
  CROSS_CFLAGS="-I/tmp/dfly/cross/simple ${BCFLAGS} -L/tmp/dfly/cross/lib" \
  MACHINE="x86_64" MACHINE_ARCH="x86_64" MACHINE_PLATFORM="pc64" \
  HOST_BINUTILSVER="${PHOSTbinutils}" -DNO_TOOLCHAIN \
  -DNO_ALTBINUTILS -DNO_ALTCOMPILER -DNOPROFILE -DWANT_INSTALLER -DNO_INITRD \
  > /tmp/dfly/worldo.log 2>&1 || (echo "  error: see worldo.log" && exit 4)
  [ ! -f ${TIMELOG:-/blah} ] || /tmp/dfly/cross/cat ${TIMELOG}
}

build_world_tc () {
  cd $P && \
  ${TIMECMD} /tmp/dfly/cross/make -j${MJ} quickworld \
  _HOSTPATH="/tmp/dfly/cross" MAKEOBJDIRPREFIX="/tmp/dfly/obj" \
  CROSS_CFLAGS="-I/tmp/dfly/cross/simple ${BCFLAGS} -L/tmp/dfly/cross/lib" \
  MACHINE="x86_64" MACHINE_ARCH="x86_64" MACHINE_PLATFORM="pc64" \
  HOST_BINUTILSVER="${PHOSTbinutils}" \
  -DNO_ALTBINUTILS -DNO_ALTCOMPILER -DNOPROFILE -DWANT_INSTALLER -DNO_INITRD \
  > /tmp/dfly/worldc.log 2>&1 || (echo "  error: see worldc.log" && exit 4)
  [ ! -f ${TIMELOG:-/blah} ] || /tmp/dfly/cross/cat ${TIMELOG}
}

build_kernel_nokmod () {
  cd $P && \
  ${TIMECMD} /tmp/dfly/cross/make -j${MJ} buildkernel \
  _HOSTPATH="/tmp/dfly/cross" MAKEOBJDIRPREFIX="/tmp/dfly/obj" \
  HOST_BINUTILSVER="${PHOSTbinutils}" -DNO_MODULES \
  MACHINE="x86_64" MACHINE_ARCH="x86_64" MACHINE_PLATFORM="pc64" \
  -DNO_ALTBINUTILS -DNO_ALTCOMPILER -DNOPROFILE \
  > /tmp/dfly/kernelo.log 2>&1 || (echo "  error: see kernelo.log" && exit 5)
  [ ! -f ${TIMELOG:-/blah} ] || /tmp/dfly/cross/cat ${TIMELOG}
}

build_kernel_kmod () {
  # XXX for now rebuild kernel too, build.sh quickernel bug in:
  # cc: error: smbus_if.c: No such file or directory
  cd $P && \
  ${TIMECMD} /tmp/dfly/cross/make -j${MJ} quickkernel \
  _HOSTPATH="/tmp/dfly/cross" MAKEOBJDIRPREFIX="/tmp/dfly/obj" \
  HOST_BINUTILSVER="${PHOSTbinutils}" \
  MACHINE="x86_64" MACHINE_ARCH="x86_64" MACHINE_PLATFORM="pc64" \
  -DNO_ALTBINUTILS -DNO_ALTCOMPILER -DNOPROFILE \
  > /tmp/dfly/kernelm.log 2>&1 || (echo "  error: see kernelm.log" && exit 5)
  [ ! -f ${TIMELOG:-/blah} ] || /tmp/dfly/cross/cat ${TIMELOG}
}

install_world () {
  cd $P && \
  ${TIMECMD} /tmp/dfly/cross/make installworld DESTDIR="/tmp/dfly/dest" \
  _HOSTPATH="/tmp/dfly/cross" MAKEOBJDIRPREFIX="/tmp/dfly/obj" \
  CROSS_CFLAGS="-I/tmp/dfly/cross/simple ${BCFLAGS} -L/tmp/dfly/cross/lib" \
  MACHINE="x86_64" MACHINE_ARCH="x86_64" MACHINE_PLATFORM="pc64" \
  HOST_BINUTILSVER="${PHOSTbinutils}" \
  -DNO_ALTBINUTILS -DNO_ALTCOMPILER -DNOPROFILE -DWANT_INSTALLER -DNO_INITRD \
  -DNOFSCHG INSTALL="install -U" TERMINFO_ENTRIES="" ZIC_UG_FLAGS="" \
  > /tmp/dfly/iworld.log 2>&1 || (echo "  error: see iworld.log" && exit 6)
  [ ! -f ${TIMELOG:-/blah} ] || /tmp/dfly/cross/cat ${TIMELOG}
  [ ! -d /tmp/dfly/obj/$P/world_x86_64/$P/share/terminfo/terminfo ] || \
    /tmp/dfly/cross/cpdup -o \
      /tmp/dfly/obj/$P/world_x86_64/$P/share/terminfo/terminfo \
      /tmp/dfly/dest/usr/share/terminfo || true
}

install_kernel () {
  cd $P && \
  ${TIMECMD} /tmp/dfly/cross/make reinstallkernel DESTDIR="/tmp/dfly/dest" \
  _HOSTPATH="/tmp/dfly/cross" MAKEOBJDIRPREFIX="/tmp/dfly/obj" \
  HOST_BINUTILSVER="${PHOSTbinutils}" \
  MACHINE="x86_64" MACHINE_ARCH="x86_64" MACHINE_PLATFORM="pc64" \
  -DNO_ALTBINUTILS -DNO_ALTCOMPILER -DNOPROFILE \
  -DNOFSCHG INSTALL="install -U" \
  > /tmp/dfly/ikernel.log 2>&1 || (echo "  error: see ikernel.log" && exit 7)
  [ ! -f ${TIMELOG:-/blah} ] || /tmp/dfly/cross/cat ${TIMELOG}
}

customize_destdir () {
  cd $P/etc &&
    /tmp/dfly/cross/make distribution DESTDIR="/tmp/dfly/dest" \
  _HOSTPATH="/tmp/dfly/cross" MAKEOBJDIRPREFIX="/tmp/dfly/obj/custom" \
  HOST_BINUTILSVER="${PHOSTbinutils}" \
  MACHINE="x86_64" MACHINE_ARCH="x86_64" MACHINE_PLATFORM="pc64" \
  -DNOFSCHG INSTALL="install -U" \
  > /tmp/dfly/icustom.log 2>&1 || (echo "  error: see icustom.log" && exit 8)
  /tmp/dfly/cross/mv -v /tmp/dfly/dest/etc /tmp/dfly/dest/etc.hdd
  /tmp/dfly/cross/mv -v /tmp/dfly/dest/root /tmp/dfly/dest/root.hdd
  /tmp/dfly/cross/mkdir /tmp/dfly/dest/root
  /tmp/dfly/cross/mkdir -p /tmp/dfly/dest/usr/local/etc
  [ ! -f /tmp/dfly/dest/share/examples/ssl/cert.pem ] ||
    /tmp/dfly/cross/cp -v /tmp/dfly/dest/share/examples/ssl/cert.pem \
    /tmp/dfly/dest/etc.hdd/etc/ssl
}

################

export LC_ALL=C

CROSSCFLAGS="-I/tmp/dfly/cross/compat -L/tmp/dfly/cross/lib"
CROSSCFLAGS="${CROSSCFLAGS} -Dpacify_glibc_headers_GCC"
CROSSCFLAGS="${CROSSCFLAGS} -DPACIFY_UNUSED"  # for shims testing only
#

if [ -f /tmp/dfly/obj/$P/ctools_x86_64_x86_64/.cross_done ]; then
echo "crosstools done marker detected, skipping"
prepare_compat
else
prepare_compat
fake_libutil
fake_awk
fake_date
fake_chflags
fake_hostname
fake_sysctl
fake_uname
fake_mkdep
bootstrap_bmake
bootstrap_cat
bootstrap_chmod
bootstrap_cp
bootstrap_env
bootstrap_install
bootstrap_stat
bootstrap_sync
bootstrap_time
bootstrap_uniq
bootstrap_xargs
bootstrap_wc
bootstrap_ln
bootstrap_mv
bootstrap_rm
bootstrap_printf
bootstrap_touch
bootstrap_mkdir
bootstrap_mtree
bootstrap_sed
bootstrap_tr
bootstrap_yacc
#tbd bootstrap_lex
bootstrap_mktemp
bootstrap_find
bootstrap_join
bootstrap_sort
bootstrap_tsort
bootstrap_lorder
bootstrap_cap_mkdb
bootstrap_pwd_mkdb
echo ""

TIMELOG=/tmp/dfly/time.log
#TIMECMD=time
TIMECMD="/tmp/dfly/cross/time -o ${TIMELOG}"

#export PATH="/tmp/dfly/cross:${PATH}"
export PATH="/tmp/dfly/cross:/bin:/usr/bin"
BCFLAGS=""
#
cp -f $P/lib/libz/zconf.h /tmp/dfly/cross/compat/zconf.h
cp -f $P/contrib/zlib*/zlib.h /tmp/dfly/cross/compat/zlib.h
#
echo "Building btools:"
build_btools
#
bootstrap_libs
fake_awk2
fake_cpdup2
fake_date2
fake_dd2
fake_chflags2
fake_hostname2
fake_pwd_mkdb2
fake_uname2
fake_mkdep2
echo ""
#
MJ=$(/tmp/dfly/cross/sysctl -n hw.ncpu) # overridable with MAKE_JOBS=N env
echo "Using MAKE_JOBS=${MJ}"
echo "Building ctools:"
build_ctools
#
rm -rf /tmp/dfly/obj/$P/bin
rm -rf /tmp/dfly/obj/$P/sbin
rm -rf /tmp/dfly/obj/$P/gnu
rm -rf /tmp/dfly/obj/$P/lib
rm -rf /tmp/dfly/obj/$P/usr.bin
rm -rf /tmp/dfly/obj/$P/usr.sbin
fi # cross-tools
#
MJ=$(/tmp/dfly/cross/sysctl -n hw.ncpu)
#
echo "Building world:"
export PATH="/tmp/dfly/cross"
if [ -z "${PSPLITtoolchain}" ] ; then
 build_world
else
 echo " building userland:"
 build_world_notc
 echo " building toolchain:"
 build_world_tc
fi
#
echo "Building kernel:"
export PATH="/tmp/dfly/cross"
if [ -z "${PSPLITmodules}" ] ; then
 build_kernel
else
 echo " building kernel only:"
 build_kernel_nokmod
 echo " building kernel with modules:"
 # XXX smbus_if.o search issue build_kernel_kmod
 build_kernel
fi
#
echo ""
echo "Build is done:"
echo "  build logs are in /tmp/dfly/*.log"

fake_pw3
fake_makedb3
mkdir -p /tmp/dfly/dest
echo "Installing world into /tmp/dfly/dest/"
install_world
echo "Installing kernel into /tmp/dfly/dest/boot/kernel"
install_kernel

mkdir -p /tmp/dfly/obj/custom
echo "Customizing destdir"
customize_destdir
echo ""
echo "  DragonFly base is available in /tmp/dfly/dest/"
echo ""
# FIN
#
# to generate bootable dfly.iso image mkisofs is needed from cdrtools
# cp -r /tmp/dfly/dest/etc.hdd /tmp/dfly/dest/etc
# cp -r /tmp/dfly/dest/root.hdd /tmp/dfly/dest/root
# cp -f nrelease/root/etc/fstab /tmp/dfly/dest/etc/fstab
# cp -f nrelease/root/boot/loader.conf /tmp/dfly/dest/boot/loader.conf
# mkisofs -uid 0 -gid 0 -R -J -b boot/cdboot -no-emul-boot -V DFLY \
#         -o /tmp/dfly.iso /tmp/dfly/dest
