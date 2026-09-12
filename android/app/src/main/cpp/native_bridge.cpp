#include <jni.h>
#include <string>
#include <android/log.h>

#define TAG "iTantraNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_itantra_1app_MainActivity_getSherpaEngineVersion(
        JNIEnv* env,
        jobject /* this */) {
    std::string version = "sherpa-onnx-v1.13.8-int8-edge";
    LOGI("Sherpa Engine initialized: %s", version.c_str());
    return env->NewStringUTF(version.c_str());
}
