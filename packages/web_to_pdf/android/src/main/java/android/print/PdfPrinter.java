package android.print;

import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;

import java.io.File;
import java.io.IOException;

/**
 * Writes a {@link PrintDocumentAdapter}'s output to a file without the print
 * dialog (DK-0399). It lives in {@code android.print} because the adapter's
 * layout and write callbacks can only be created from this package.
 */
public final class PdfPrinter {
    private PdfPrinter() {}

    /** Called once on the main thread: {@code error} is null on success. */
    public interface Done {
        void onDone(String error);
    }

    public static void print(PrintDocumentAdapter adapter, PrintAttributes attributes, File out, Done done) {
        adapter.onStart();
        adapter.onLayout(null, attributes, new CancellationSignal(), new PrintDocumentAdapter.LayoutResultCallback() {
            @Override
            public void onLayoutFinished(PrintDocumentInfo info, boolean changed) {
                final ParcelFileDescriptor fd;
                try {
                    fd = ParcelFileDescriptor.open(out, ParcelFileDescriptor.MODE_CREATE
                            | ParcelFileDescriptor.MODE_TRUNCATE | ParcelFileDescriptor.MODE_READ_WRITE);
                } catch (IOException e) {
                    adapter.onFinish();
                    done.onDone(e.toString());
                    return;
                }
                adapter.onWrite(new PageRange[] {PageRange.ALL_PAGES}, fd, new CancellationSignal(),
                        new PrintDocumentAdapter.WriteResultCallback() {
                            @Override
                            public void onWriteFinished(PageRange[] pages) {
                                close(fd);
                                adapter.onFinish();
                                done.onDone(null);
                            }

                            @Override
                            public void onWriteFailed(CharSequence error) {
                                close(fd);
                                adapter.onFinish();
                                done.onDone(String.valueOf(error));
                            }
                        });
            }

            @Override
            public void onLayoutFailed(CharSequence error) {
                adapter.onFinish();
                done.onDone(String.valueOf(error));
            }
        }, null);
    }

    private static void close(ParcelFileDescriptor fd) {
        try {
            fd.close();
        } catch (IOException ignored) {
            // The PDF is written; a failed close leaves nothing to undo.
        }
    }
}
