package io.github.hoadl114514.netease_client

import com.ryanheise.audioservice.AudioServiceActivity

// 继承 AudioServiceActivity，让界面和后台播放服务共用同一个 FlutterEngine。
class MainActivity : AudioServiceActivity()
