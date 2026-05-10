#include "my_application.h"
#include <clocale>

int main(int argc, char** argv) {
  // media_kit/mpv requires numeric locale to be C for decimal parsing.
  setlocale(LC_NUMERIC, "C");
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
