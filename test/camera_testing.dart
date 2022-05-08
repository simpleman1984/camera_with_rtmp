// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:camera_with_rtmp_phiz/new/common/camera_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@visibleForTesting
class CameraTesting {
  CameraTesting._();

  static final MethodChannel channel = CameraChannel.channel;

  static int get nextHandle => CameraChannel.nextHandle;

  static set nextHandle(int handle) => CameraChannel.nextHandle = handle;
}