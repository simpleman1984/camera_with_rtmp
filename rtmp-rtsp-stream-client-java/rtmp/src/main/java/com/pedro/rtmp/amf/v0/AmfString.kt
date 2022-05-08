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

package com.pedro.rtmp.amf.v0

import com.pedro.rtmp.utils.readUInt16
import com.pedro.rtmp.utils.readUntil
import com.pedro.rtmp.utils.writeUInt16
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import kotlin.jvm.Throws

/**
 * Created by pedro on 8/04/21.
 *
 * A string encoded in ASCII where 2 first bytes indicate string size
 */
class AmfString(var value: String = ""): AmfData() {

  private var bodySize: Int = value.toByteArray(Charsets.US_ASCII).size + 2

  @Throws(IOException::class)
  override fun readBody(input: InputStream) {
    //read value size as UInt16
    bodySize = input.readUInt16()
    //read value in ASCII
    val bytes = ByteArray(bodySize)
    bodySize += 2
    input.readUntil(bytes)
    value = String(bytes, Charsets.US_ASCII)
  }

  @Throws(IOException::class)
  override fun writeBody(output: OutputStream) {
    val bytes = value.toByteArray(Charsets.US_ASCII)
    //write value size as UInt16. Value size not included
    output.writeUInt16(bodySize - 2)
    //write value bytes in ASCII
    output.write(bytes)
  }

  override fun getType(): AmfType = AmfType.STRING

  override fun getSize(): Int = bodySize

  override fun toString(): String {
    return "AmfString value: $value"
  }
}