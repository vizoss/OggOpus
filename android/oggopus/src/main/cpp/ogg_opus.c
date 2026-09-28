#include <jni.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ogg-opus/opusaudio.h"
#include "ogg-opus/log.h"
#include "ogg-opus/config.h"
#include <errno.h>


#ifdef __cplusplus
extern "C" {
#endif

int jstrToChar(JNIEnv *env, jstring inStr, char *outBuffer) {
    if (inStr == NULL)
        return 0;
    int len = 0;
    len = (*env)->GetStringLength(env, inStr);
    (*env)->GetStringUTFRegion(env, inStr, 0, len, outBuffer);
    return len;
}


JNIEXPORT jstring
JNICALL Java_com_thk_oggopus_OggOpusNative_nativeGetString
        (JNIEnv *env, jobject obj) {
    char buf[] = "Hello from OggOpus !";
    return (*env)->NewStringUTF(env, buf);
}

JNIEXPORT jint
JNICALL Java_com_thk_oggopus_OggOpusNative_encode
        (JNIEnv *env, jobject obj, jstring fileIn, jstring fileOut, jstring option) {

    char bufFileIn[256] = {0}, bufFileOut[256] = {0}, bufFileOp[MAX_CMD_BUFFER] = {0};
    int rst = 1;
    jstrToChar(env, fileIn, bufFileIn);
    jstrToChar(env, fileOut, bufFileOut);
    jstrToChar(env, option, bufFileOp);
    rst = encode(bufFileIn, bufFileOut, bufFileOp);
    return rst;
}

JNIEXPORT jint
JNICALL Java_com_thk_oggopus_OggOpusNative_decode
        (JNIEnv *env, jobject obj, jstring fileIn, jstring fileOut, jstring option) {

    char bufFileIn[256] = {0}, bufFileOut[256] = {0}, bufFileOp[MAX_CMD_BUFFER] = {0};
    int rst = 1;
    jstrToChar(env, fileIn, bufFileIn);
    jstrToChar(env, fileOut, bufFileOut);
    jstrToChar(env, option, bufFileOp);
    rst = decode(bufFileIn, bufFileOut, bufFileOp);
    return rst;
}

JNIEXPORT jint
JNICALL Java_com_thk_oggopus_OggOpusNative_startRecording
        (JNIEnv *env, jobject obj, jstring fileIn) {
    char bufFileIn[256] = {0};
    jstrToChar(env, fileIn, bufFileIn);
    return startRecording(bufFileIn);
}

JNIEXPORT void JNICALL
Java_com_thk_oggopus_OggOpusNative_stopRecording(
        JNIEnv *env,
        jobject obj
) {
    return stopRecording();
}

JNIEXPORT jint
JNICALL Java_com_thk_oggopus_OggOpusNative_play(
        JNIEnv *env,
        jobject obj,
        jstring fileIn
) {

    char bufFileIn[256] = {0};
    jstrToChar(env, fileIn, bufFileIn);
    return 0;
}

JNIEXPORT void JNICALL
Java_com_thk_oggopus_OggOpusNative_stopPlaying(
        JNIEnv *env, jobject obj
) {
//	stopPlaying();
//to do:
}

JNIEXPORT jint
JNICALL Java_com_thk_oggopus_OggOpusNative_writeFrame(
        JNIEnv *env,
        jobject obj,
        jobject buffer,
        jint len
) {

    jbyte *bufferBytes = (*env)->GetDirectBufferAddress(env, buffer);
    return writeFrame((uint8_t *) bufferBytes, len
    );
}

JNIEXPORT jint
JNICALL Java_com_thk_oggopus_OggOpusNative_isOpusFile(
        JNIEnv *env,
        jobject obj,
        jstring fileIn
) {
    char bufFileIn[256] = {0};
    jstrToChar(env, fileIn, bufFileIn
    );

    return isOpusFile(bufFileIn);
}

/*
 * Class:     top_oply_opuslib_OpusTool
 * Method:    openOpusFile
 * Signature: (Ljava/lang/String;)I
 */
JNIEXPORT jint
JNICALL Java_com_thk_oggopus_OggOpusNative_openOpusFile(
        JNIEnv *env,
        jobject obj,
        jstring fileIn
) {
    char bufFileIn[256] = {0};
    jstrToChar(env, fileIn, bufFileIn);
    return openOpusFile(bufFileIn);
}

JNIEXPORT jint
JNICALL Java_com_thk_oggopus_OggOpusNative_seekOpusFile(
        JNIEnv *env,
        jobject obj,
        jfloat position
) {
    return
            seekOpusFile(position);
}

JNIEXPORT void JNICALL
Java_com_thk_oggopus_OggOpusNative_closeOpusFile(
        JNIEnv *env,
        jobject obj
) {
    return closeOpusFile();
}

JNIEXPORT void JNICALL
Java_com_thk_oggopus_OggOpusNative_readOpusFile(
        JNIEnv *env,
        jobject obj,
        jobject buffer,
        jint capacity
) {
    jbyte *bufferBytes = (*env)->GetDirectBufferAddress(env, buffer);
    return readOpusFile((uint8_t *) bufferBytes, capacity);
}

JNIEXPORT jint
JNICALL Java_com_thk_oggopus_OggOpusNative_getFinished(
        JNIEnv *env,
        jobject obj
) {
    return getFinished();

}


JNIEXPORT jint
JNICALL Java_com_thk_oggopus_OggOpusNative_getSize(
        JNIEnv *env,
        jobject obj
) {
    return getSize();
}


JNIEXPORT jlong
JNICALL Java_com_thk_oggopus_OggOpusNative_getPcmOffset(
        JNIEnv *env,
        jobject obj
) {
    return getPcmOffset();
}

JNIEXPORT jlong
JNICALL Java_com_thk_oggopus_OggOpusNative_getTotalPcmDuration(
        JNIEnv *env,
        jobject obj) {
    return getTotalPcmDuration();
}


#ifdef __cplusplus
}
#endif
