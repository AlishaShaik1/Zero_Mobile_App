class AppConstants {
  // ASR: ~42 MB streaming Zipformer (English)
  static const asrUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
      'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17.tar.bz2';
  static const expectedEncoderBytes = 41 * 1024 * 1024;

  // KWS: ~11 MB Zipformer keyword spotter (GigaSpeech, English, open-vocab)
  static const kwsUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/kws-models/'
      'sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01.tar.bz2';

  // TTS: ~60 MB VITS Piper single-speaker (jenny_dioco)
  static const ttsUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/'
      'vits-piper-en_GB-jenny_dioco-medium.tar.bz2';
}
