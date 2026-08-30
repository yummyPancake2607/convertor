#include <convertor/conversion_settings.hpp>
#include <cassert>
#include <iostream>

using namespace convertor;
using namespace std;

void test_settings() {
    ConversionSettings settings;
    settings.fast_start = true;
    settings.overwrite = false;

    settings.video.width = 1920;
    settings.video.height = 1080;
    settings.video.crf = 23;

    assert(settings.video.width.value() == 1920);
    assert(settings.video.height.value() == 1080);
    assert(settings.video.crf.value() == 23);

    settings.audio.sample_rate = 44100;
    settings.audio.channels = 2;
    assert(settings.audio.sample_rate.value() == 44100);
}
