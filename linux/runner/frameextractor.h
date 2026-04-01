#ifndef FLUTTER_FRAMEEXTRACTOR_H_
#define FLUTTER_FRAMEEXTRACTOR_H_

#include <gtk/gtk.h>

G_DECLARE_FINAL_TYPE(FrameExtractor,
                     frameextractor,
                     FRAME_EXTRACTOR,
                     APP,
                     GtkApplication)

FrameExtractor* frameextractor_new();

#endif
