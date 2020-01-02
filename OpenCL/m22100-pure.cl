/**
 * Author......: See docs/credits.txt
 * License.....: MIT
 */

#define NEW_SIMD_CODE

#ifdef KERNEL_STATIC
#include "inc_vendor.h"
#include "inc_types.h"
#include "inc_platform.cl"
#include "inc_common.cl"
#include "inc_simd.cl"
#include "inc_hash_sha256.cl"
#include "inc_cipher_aes.cl"
#endif

#define ITERATION_BITLOCKER 0x100000
#define SALT_LEN_BITLOCKER  16
#define IV_LEN_BITLOCKER    12
#define DATA_LEN_BITLOCKER  60

typedef struct bitlocker
{
  u32 type;
  u32 iv[4];
  u32 data[15];
  u32 wb_ke_pc[ITERATION_BITLOCKER][48];

} bitlocker_t;

typedef struct bitlocker_tmp
{
  u32 last_hash[8];
  u32 init_hash[8];

} bitlocker_tmp_t;

#ifdef REAL_SHM
#define SHM_TYPE2 LOCAL_AS
#else
#define SHM_TYPE2 GLOBAL_AS
#endif

DECLSPEC void sha256_transform_vector_pc (const u32x *w0, const u32x *w1, const u32x *w2, const u32x *w3, u32x *digest, SHM_TYPE2 u32 s_wb_ke_pc[48])
{
  u32x a = digest[0];
  u32x b = digest[1];
  u32x c = digest[2];
  u32x d = digest[3];
  u32x e = digest[4];
  u32x f = digest[5];
  u32x g = digest[6];
  u32x h = digest[7];

  u32x w0_t = w0[0];
  u32x w1_t = w0[1];
  u32x w2_t = w0[2];
  u32x w3_t = w0[3];
  u32x w4_t = w1[0];
  u32x w5_t = w1[1];
  u32x w6_t = w1[2];
  u32x w7_t = w1[3];
  u32x w8_t = w2[0];
  u32x w9_t = w2[1];
  u32x wa_t = w2[2];
  u32x wb_t = w2[3];
  u32x wc_t = w3[0];
  u32x wd_t = w3[1];
  u32x we_t = w3[2];
  u32x wf_t = w3[3];

  #define ROUND_EXPAND_PC(i)    \
  {                             \
    w0_t = s_wb_ke_pc[i +  0];  \
    w1_t = s_wb_ke_pc[i +  1];  \
    w2_t = s_wb_ke_pc[i +  2];  \
    w3_t = s_wb_ke_pc[i +  3];  \
    w4_t = s_wb_ke_pc[i +  4];  \
    w5_t = s_wb_ke_pc[i +  5];  \
    w6_t = s_wb_ke_pc[i +  6];  \
    w7_t = s_wb_ke_pc[i +  7];  \
    w8_t = s_wb_ke_pc[i +  8];  \
    w9_t = s_wb_ke_pc[i +  9];  \
    wa_t = s_wb_ke_pc[i + 10];  \
    wb_t = s_wb_ke_pc[i + 11];  \
    wc_t = s_wb_ke_pc[i + 12];  \
    wd_t = s_wb_ke_pc[i + 13];  \
    we_t = s_wb_ke_pc[i + 14];  \
    wf_t = s_wb_ke_pc[i + 15];  \
  }

  #define ROUND_STEP(i)                                                                   \
  {                                                                                       \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w0_t, k_sha256[i +  0]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w1_t, k_sha256[i +  1]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, w2_t, k_sha256[i +  2]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, w3_t, k_sha256[i +  3]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, w4_t, k_sha256[i +  4]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, w5_t, k_sha256[i +  5]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, w6_t, k_sha256[i +  6]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, w7_t, k_sha256[i +  7]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, a, b, c, d, e, f, g, h, w8_t, k_sha256[i +  8]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, h, a, b, c, d, e, f, g, w9_t, k_sha256[i +  9]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, g, h, a, b, c, d, e, f, wa_t, k_sha256[i + 10]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, f, g, h, a, b, c, d, e, wb_t, k_sha256[i + 11]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, e, f, g, h, a, b, c, d, wc_t, k_sha256[i + 12]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, d, e, f, g, h, a, b, c, wd_t, k_sha256[i + 13]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, c, d, e, f, g, h, a, b, we_t, k_sha256[i + 14]); \
    SHA256_STEP (SHA256_F0o, SHA256_F1o, b, c, d, e, f, g, h, a, wf_t, k_sha256[i + 15]); \
  }

  ROUND_STEP (0);

  #ifdef _unroll
  #pragma unroll
  #endif
  for (int i = 16; i < 64; i += 16)
  {
    ROUND_EXPAND_PC (i - 16); ROUND_STEP (i);
  }

  #undef ROUND_EXPAND_PC
  #undef ROUND_STEP

  digest[0] += a;
  digest[1] += b;
  digest[2] += c;
  digest[3] += d;
  digest[4] += e;
  digest[5] += f;
  digest[6] += g;
  digest[7] += h;
}

KERNEL_FQ void m22100_init (KERN_ATTR_TMPS_ESALT (bitlocker_tmp_t, bitlocker_t))
{
  /**
   * base
   */

  const u64 gid = get_global_id (0);

  if (gid >= gid_max) return;

  // sha256 of utf16le converted password:

  sha256_ctx_t ctx0;

  sha256_init (&ctx0);

  sha256_update_global_utf16le_swap (&ctx0, pws[gid].i, pws[gid].pw_len);

  sha256_final (&ctx0);

  u32 w[16] = { 0 }; // 64 bytes blocks/aligned, we need 32 bytes

  w[0] = ctx0.h[0];
  w[1] = ctx0.h[1];
  w[2] = ctx0.h[2];
  w[3] = ctx0.h[3];
  w[4] = ctx0.h[4];
  w[5] = ctx0.h[5];
  w[6] = ctx0.h[6];
  w[7] = ctx0.h[7];

  // sha256 of sha256:

  sha256_ctx_t ctx1;

  sha256_init   (&ctx1);
  sha256_update (&ctx1, w, 32);
  sha256_final  (&ctx1);

  // set tmps:

  tmps[gid].init_hash[0] = ctx1.h[0];
  tmps[gid].init_hash[1] = ctx1.h[1];
  tmps[gid].init_hash[2] = ctx1.h[2];
  tmps[gid].init_hash[3] = ctx1.h[3];
  tmps[gid].init_hash[4] = ctx1.h[4];
  tmps[gid].init_hash[5] = ctx1.h[5];
  tmps[gid].init_hash[6] = ctx1.h[6];
  tmps[gid].init_hash[7] = ctx1.h[7];

  tmps[gid].last_hash[0] = 0;
  tmps[gid].last_hash[1] = 0;
  tmps[gid].last_hash[2] = 0;
  tmps[gid].last_hash[3] = 0;
  tmps[gid].last_hash[4] = 0;
  tmps[gid].last_hash[5] = 0;
  tmps[gid].last_hash[6] = 0;
  tmps[gid].last_hash[7] = 0;
}

KERNEL_FQ void m22100_loop (KERN_ATTR_TMPS_ESALT (bitlocker_tmp_t, bitlocker_t))
{
  const u64 gid = get_global_id (0);
  const u64 lid = get_local_id (0);
  const u64 lsz = get_local_size (0);

  // init

  u32x w0[4];
  u32x w1[4];
  u32x w2[4];
  u32x w3[4];

  w0[0] = packv (tmps, last_hash, gid, 0); // last_hash
  w0[1] = packv (tmps, last_hash, gid, 1);
  w0[2] = packv (tmps, last_hash, gid, 2);
  w0[3] = packv (tmps, last_hash, gid, 3);
  w1[0] = packv (tmps, last_hash, gid, 4);
  w1[1] = packv (tmps, last_hash, gid, 5);
  w1[2] = packv (tmps, last_hash, gid, 6);
  w1[3] = packv (tmps, last_hash, gid, 7);
  w2[0] = packv (tmps, init_hash, gid, 0); // init_hash
  w2[1] = packv (tmps, init_hash, gid, 1);
  w2[2] = packv (tmps, init_hash, gid, 2);
  w2[3] = packv (tmps, init_hash, gid, 3);
  w3[0] = packv (tmps, init_hash, gid, 4);
  w3[1] = packv (tmps, init_hash, gid, 5);
  w3[2] = packv (tmps, init_hash, gid, 6);
  w3[3] = packv (tmps, init_hash, gid, 7);

  // salt to register

  u32x t0[4];
  u32x t1[4];
  u32x t2[4];
  u32x t3[4];

  t0[0] = salt_bufs[salt_pos].salt_buf[0];
  t0[1] = salt_bufs[salt_pos].salt_buf[1];
  t0[2] = salt_bufs[salt_pos].salt_buf[2];
  t0[3] = salt_bufs[salt_pos].salt_buf[3];
  t1[0] = 0;
  t1[1] = 0;
  t1[2] = 0x80000000;
  t1[3] = 0;
  t2[0] = 0;
  t2[1] = 0;
  t2[2] = 0;
  t2[3] = 0;
  t3[0] = 0;
  t3[1] = 0;
  t3[2] = 0;
  t3[3] = 88 * 8;

  /**
   * load FIXED_ITER_COUNT full w[] precomputed KE buffers into shared memory since its all static data
   * in order for this to work we need to set a fixed loop count to FIXED_ITER_COUNT
   * We also need to handle OpenCL and CUDA differently because of:
   * ptxas error   : Entry function 'm22100_loop' uses too much shared data (0xc004 bytes, 0xc000 max)
   */

  #ifdef IS_CUDA
  #define FIXED_ITER_COUNT 256
  #else
  #define FIXED_ITER_COUNT 128
  #endif

  #ifdef REAL_SHM
  LOCAL_VK u32 s_wb_ke_pc[FIXED_ITER_COUNT][48];
  #else
  GLOBAL_AS u32 (*s_wb_ke_pc)[48] = NULL;
  #endif

  #ifdef REAL_SHM

  for (u32 i = lid; i < FIXED_ITER_COUNT; i += lsz)
  {
    for (u32 j = 0; j < 48; j++) // first 16 set to register
    {
      s_wb_ke_pc[i][j] = esalt_bufs[digests_offset].wb_ke_pc[loop_pos + i][j];
    }
  }

  SYNC_THREADS ();

  #else

  s_wb_ke_pc = &esalt_bufs[digests_offset].wb_ke_pc[loop_pos];

  #endif

  // main loop

  for (u32 i = 0, j = loop_pos; i < FIXED_ITER_COUNT; i++, j++)
  {
    u32x digest[8];

    digest[0] = SHA256M_A;
    digest[1] = SHA256M_B;
    digest[2] = SHA256M_C;
    digest[3] = SHA256M_D;
    digest[4] = SHA256M_E;
    digest[5] = SHA256M_F;
    digest[6] = SHA256M_G;
    digest[7] = SHA256M_H;

    sha256_transform_vector (w0, w1, w2, w3, digest);

    t1[0] = hc_swap32_S (j); // only moving part

    sha256_transform_vector_pc (t0, t1, t2, t3, digest, s_wb_ke_pc[i]);

    w0[0] = digest[0];
    w0[1] = digest[1];
    w0[2] = digest[2];
    w0[3] = digest[3];
    w1[0] = digest[4];
    w1[1] = digest[5];
    w1[2] = digest[6];
    w1[3] = digest[7];
  }

  #ifdef IS_CUDA
  // nothing to do
  #else
  // remaining 128 iterations for non-cuda devices
  #ifdef REAL_SHM

  for (u32 i = lid; i < FIXED_ITER_COUNT; i += lsz)
  {
    for (u32 j = 0; j < 48; j++) // first 16 set to register
    {
      s_wb_ke_pc[i][j] = esalt_bufs[digests_offset].wb_ke_pc[loop_pos + 128 + i][j];
    }
  }

  SYNC_THREADS ();

  #else

  s_wb_ke_pc = &esalt_bufs[digests_offset].wb_ke_pc[loop_pos + 128];

  #endif

  // main loop

  for (u32 i = 0, j = loop_pos + 128; i < FIXED_ITER_COUNT; i++, j++)
  {
    u32x digest[8];

    digest[0] = SHA256M_A;
    digest[1] = SHA256M_B;
    digest[2] = SHA256M_C;
    digest[3] = SHA256M_D;
    digest[4] = SHA256M_E;
    digest[5] = SHA256M_F;
    digest[6] = SHA256M_G;
    digest[7] = SHA256M_H;

    sha256_transform_vector (w0, w1, w2, w3, digest);

    t1[0] = hc_swap32_S (j); // only moving part

    sha256_transform_vector_pc (t0, t1, t2, t3, digest, s_wb_ke_pc[i]);

    w0[0] = digest[0];
    w0[1] = digest[1];
    w0[2] = digest[2];
    w0[3] = digest[3];
    w1[0] = digest[4];
    w1[1] = digest[5];
    w1[2] = digest[6];
    w1[3] = digest[7];
  }
  #endif

  unpackv (tmps, last_hash, gid, 0, w0[0]);
  unpackv (tmps, last_hash, gid, 1, w0[1]);
  unpackv (tmps, last_hash, gid, 2, w0[2]);
  unpackv (tmps, last_hash, gid, 3, w0[3]);
  unpackv (tmps, last_hash, gid, 4, w1[0]);
  unpackv (tmps, last_hash, gid, 5, w1[1]);
  unpackv (tmps, last_hash, gid, 6, w1[2]);
  unpackv (tmps, last_hash, gid, 7, w1[3]);
}

KERNEL_FQ void m22100_comp (KERN_ATTR_TMPS_ESALT (bitlocker_tmp_t, bitlocker_t))
{
  const u64 gid = get_global_id (0);
  const u64 lid = get_local_id (0);
  const u64 lsz = get_local_size (0);

  /**
   * aes shared
   */

  #ifdef REAL_SHM

  LOCAL_VK u32 s_td0[256];
  LOCAL_VK u32 s_td1[256];
  LOCAL_VK u32 s_td2[256];
  LOCAL_VK u32 s_td3[256];
  LOCAL_VK u32 s_td4[256];

  LOCAL_VK u32 s_te0[256];
  LOCAL_VK u32 s_te1[256];
  LOCAL_VK u32 s_te2[256];
  LOCAL_VK u32 s_te3[256];
  LOCAL_VK u32 s_te4[256];

  for (u32 i = lid; i < 256; i += lsz)
  {
    s_td0[i] = td0[i];
    s_td1[i] = td1[i];
    s_td2[i] = td2[i];
    s_td3[i] = td3[i];
    s_td4[i] = td4[i];

    s_te0[i] = te0[i];
    s_te1[i] = te1[i];
    s_te2[i] = te2[i];
    s_te3[i] = te3[i];
    s_te4[i] = te4[i];
  }

  SYNC_THREADS ();

  #else

  CONSTANT_AS u32a *s_td0 = td0;
  CONSTANT_AS u32a *s_td1 = td1;
  CONSTANT_AS u32a *s_td2 = td2;
  CONSTANT_AS u32a *s_td3 = td3;
  CONSTANT_AS u32a *s_td4 = td4;

  CONSTANT_AS u32a *s_te0 = te0;
  CONSTANT_AS u32a *s_te1 = te1;
  CONSTANT_AS u32a *s_te2 = te2;
  CONSTANT_AS u32a *s_te3 = te3;
  CONSTANT_AS u32a *s_te4 = te4;

  #endif

  if (gid >= gid_max) return;

  /*
   * AES decrypt the data_buf
   */

  // init AES

  u32 ukey[8];

  ukey[0] = tmps[gid].last_hash[0];
  ukey[1] = tmps[gid].last_hash[1];
  ukey[2] = tmps[gid].last_hash[2];
  ukey[3] = tmps[gid].last_hash[3];
  ukey[4] = tmps[gid].last_hash[4];
  ukey[5] = tmps[gid].last_hash[5];
  ukey[6] = tmps[gid].last_hash[6];
  ukey[7] = tmps[gid].last_hash[7];

  #define KEYLEN 60

  u32 ks[KEYLEN];

  AES256_set_encrypt_key (ks, ukey, s_te0, s_te1, s_te2, s_te3);

  // decrypt:

  u32 iv[4];

  iv[0] = esalt_bufs[digests_offset].iv[0];
  iv[1] = esalt_bufs[digests_offset].iv[1];
  iv[2] = esalt_bufs[digests_offset].iv[2];
  iv[3] = esalt_bufs[digests_offset].iv[3];

  // in total we've 60 bytes: we need out0 (16 bytes) to out3 (16 bytes) for MAC verification

  // 1

  u32 out1[4];

  AES256_encrypt (ks, iv, out1, s_te0, s_te1, s_te2, s_te3, s_te4);

  // some early reject:

  out1[0] ^= esalt_bufs[digests_offset].data[4]; // skip MAC for now (first 16 bytes)

  if ((out1[0] & 0xffff0000) != 0x2c000000) return; // data_size must be 0x2c00


  out1[1] ^= esalt_bufs[digests_offset].data[5];

  if ((out1[1] & 0xffff0000) != 0x01000000) return; // version must be 0x0100


  out1[2] ^= esalt_bufs[digests_offset].data[6];

  if ((out1[2] & 0x00ff0000) != 0x00200000) return; // v2 must be 0x20

  if ((out1[2] >> 24) > 0x05) return; // v1 must be <= 5

  // if no MAC verification should be performed, we are already done:

  u32 type = esalt_bufs[digests_offset].type;

  if (type == 0)
  {
    if (atomic_inc (&hashes_shown[digests_offset]) == 0)
    {
      mark_hash (plains_buf, d_return_buf, salt_pos, digests_cnt, 0, digests_offset + 0, gid, 0, 0, 0);
    }

    return;
  }

  out1[3] ^= esalt_bufs[digests_offset].data[7];

  /*
   * Decrypt the whole data buffer for MAC verification (type == 1):
   */

  // 0

  iv[3] = iv[3] & 0xff000000; // xx000000

  u32 out0[4];

  AES256_encrypt (ks, iv, out0, s_te0, s_te1, s_te2, s_te3, s_te4);

  out0[0] ^= esalt_bufs[digests_offset].data[0];
  out0[1] ^= esalt_bufs[digests_offset].data[1];
  out0[2] ^= esalt_bufs[digests_offset].data[2];
  out0[3] ^= esalt_bufs[digests_offset].data[3];

  // 2

  // add 2 because we already did block 1 for the early reject

  iv[3] += 2; // xx000002

  u32 out2[4];

  AES256_encrypt (ks, iv, out2, s_te0, s_te1, s_te2, s_te3, s_te4);

  out2[0] ^= esalt_bufs[digests_offset].data[ 8];
  out2[1] ^= esalt_bufs[digests_offset].data[ 9];
  out2[2] ^= esalt_bufs[digests_offset].data[10];
  out2[3] ^= esalt_bufs[digests_offset].data[11];

  // 3

  iv[3] += 1; // xx000003

  u32 out3[4]; // actually only 3 needed

  AES256_encrypt (ks, iv, out3, s_te0, s_te1, s_te2, s_te3, s_te4);

  out3[0] ^= esalt_bufs[digests_offset].data[12];
  out3[1] ^= esalt_bufs[digests_offset].data[13];
  out3[2] ^= esalt_bufs[digests_offset].data[14];

  // compute MAC:

  // out1

  iv[0] = (iv[0] & 0x00ffffff) | 0x3a000000;
  iv[3] = (iv[3] & 0xff000000) | 0x0000002c;

  u32 mac[4];

  AES256_encrypt (ks, iv, mac, s_te0, s_te1, s_te2, s_te3, s_te4);

  iv[0] = mac[0] ^ out1[0];
  iv[1] = mac[1] ^ out1[1];
  iv[2] = mac[2] ^ out1[2];
  iv[3] = mac[3] ^ out1[3];

  // out2

  AES256_encrypt (ks, iv, mac, s_te0, s_te1, s_te2, s_te3, s_te4);

  iv[0] = mac[0] ^ out2[0];
  iv[1] = mac[1] ^ out2[1];
  iv[2] = mac[2] ^ out2[2];
  iv[3] = mac[3] ^ out2[3];

  // out3

  AES256_encrypt (ks, iv, mac, s_te0, s_te1, s_te2, s_te3, s_te4);

  iv[0] = mac[0] ^ out3[0];
  iv[1] = mac[1] ^ out3[1];
  iv[2] = mac[2] ^ out3[2];
  iv[3] = mac[3];

  // final

  AES256_encrypt (ks, iv, mac, s_te0, s_te1, s_te2, s_te3, s_te4);

  if (mac[0] != out0[0]) return;
  if (mac[1] != out0[1]) return;
  if (mac[2] != out0[2]) return;
  if (mac[3] != out0[3]) return;

  // if we end up here, we are sure to have found the correct password:

  if (atomic_inc (&hashes_shown[digests_offset]) == 0)
  {
    mark_hash (plains_buf, d_return_buf, salt_pos, digests_cnt, 0, digests_offset + 0, gid, 0, 0, 0);
  }
}