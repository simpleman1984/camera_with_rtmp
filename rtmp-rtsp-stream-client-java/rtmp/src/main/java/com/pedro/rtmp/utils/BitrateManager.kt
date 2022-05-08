/*
 * Copyright (C) 2021 pedroSG94.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.pedro.rtmp.utils

/**
 * Created by pedro on 8/04/21.
 *
 * Calculate video and audio bitrate per second
 */
open class BitrateManager(private val connectCheckerRtmp: ConnectCheckerRtmp) {

  private var bitrate: Long = 0
  private var timeStamp = System.currentTimeMillis()

  @Synchronized
  fun calculateBitrate(size: Long) {
    bitrate += size
    val timeDiff = System.currentTimeMillis() - timeStamp
    if (timeDiff >= 1000) {
      connectCheckerRtmp.onNewBitrateRtmp((bitrate / (timeDiff / 1000f)).toLong())
      timeStamp = System.currentTimeMillis()
      bitrate = 0
    }
  }
}