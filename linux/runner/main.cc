#include "frameextractor.h"

int main(int argc, char** argv) {
  g_autoptr(FrameExtractor) app = frameextractor_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
