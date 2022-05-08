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

import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import kotlin.jvm.Throws

/**
 * Created by pedro on 20/04/21.
 */
abstract class AmfData {

  companion object {

    /**
     * Read unknown AmfData and convert it to specific class
     */
    @Throws(IOException::class)
    fun getAmfData(input: InputStream): AmfData {
      val amfData = when (val type = getMarkType(input.read())) {
        AmfType.NUMBER -> AmfNumber()
        AmfType.BOOLEAN -> AmfBoolean()
        AmfType.STRING -> AmfString()
        AmfType.OBJECT -> AmfObject()
        AmfType.NULL -> AmfNull()
        AmfType.UNDEFINED -> AmfUndefined()
        AmfType.ECMA_ARRAY -> AmfEcmaArray()
        AmfType.STRICT_ARRAY -> AmfStrictArray()
        else -> throw IOException("Unimplemented AMF data type: ${type.name}")
      }
      amfData.readBody(input)
      return amfData
    }

    fun getMarkType(type: Int): AmfType {
      return AmfType.values().find { it.mark.toInt() == type } ?: AmfType.STRING
    }
  }

  @Throws(IOException::class)
  fun readHeader(input: InputStream): AmfType {
    return getMarkType(input.read())
  }

  @Throws(IOException::class)
  fun writeHeader(output: OutputStream) {
    output.write(getType().mark.toInt())
  }

  @Throws(IOException::class)
  abstract fun readBody(input: InputStream)

  @Throws(IOException::class)
  abstract fun writeBody(output: OutputStream)

  abstract fun getType(): AmfType

  //Body size without header type
  abstract fun getSize(): Int
}