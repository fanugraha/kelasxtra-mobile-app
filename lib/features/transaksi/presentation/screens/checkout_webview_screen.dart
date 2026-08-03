// lib/features/transaksi/presentation/screens/checkout_webview_screen.dart
//
// WebView Midtrans Snap. Snap URL ini TIDAK punya finish_redirect_url yang
// dikonfigurasi di backend (dicek langsung ke MidtransService -- tidak ada
// Config::$finishRedirectUrl atau semacamnya), jadi kita tidak bisa
// mengandalkan navigasi WebView balik ke URL tertentu untuk tahu
// pembayaran selesai. Pendekatan yang dipakai: polling GET
// /transactions/{id} tiap beberapa detik selagi layar ini terbuka -- begitu
// status berubah dari pending, auto-tutup & laporkan hasilnya ke caller.
//
// PLATFORM: webview_flutter TIDAK punya implementasi untuk Flutter Web
// (WebViewPlatform.instance null -> crash). Target rilis app ini
// Android/iOS jadi WebView asli dipakai di sana, tapi supaya tetap bisa
// dites cepat lewat `flutter run -d chrome`, di web kita buka Snap di tab
// baru pakai url_launcher dan tetap polling status di background --
// hasilnya sama-sama terdeteksi otomatis, cuma UI pembayarannya di luar
// app untuk kasus web ini.
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/config/env.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../data/repositories/transaksi_repository.dart';
import '../providers/transaksi_provider.dart';

/// Argumen dikirim lewat go_router `extra` ke rute /checkout (bukan path
/// param biasa karena snapToken terlalu panjang/tidak URL-safe kalau
/// dipaksa jadi query param).
class CheckoutArgs {
  const CheckoutArgs({required this.transactionId, required this.snapToken});
  final int transactionId;
  final String snapToken;
}

/// Hasil yang dikembalikan ke layar sebelumnya lewat context.pop(result)
/// begitu CheckoutWebViewScreen ditutup (baik otomatis via polling maupun
/// manual lewat tombol back) -- supaya caller tahu perlu refresh data atau
/// tidak, tanpa perlu tebak-tebak dari provider invalidation semata.
class CheckoutResult {
  const CheckoutResult({required this.transactionId, required this.status});
  final int transactionId;
  final TransactionStatus status;
}

class CheckoutWebViewScreen extends ConsumerStatefulWidget {
  const CheckoutWebViewScreen({
    super.key,
    required this.transactionId,
    required this.snapToken,
  });

  final int transactionId;
  final String snapToken;

  @override
  ConsumerState<CheckoutWebViewScreen> createState() => _CheckoutWebViewScreenState();
}

class _CheckoutWebViewScreenState extends ConsumerState<CheckoutWebViewScreen> {
  WebViewController? _controller;
  late final Uri _snapUrl;
  Timer? _pollTimer;
  bool _isLoadingPage = true;
  bool _isCheckingStatus = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();

    _snapUrl = Uri.parse('${AppConfig.midtransSnapBaseUrl}/${widget.snapToken}');

    if (kIsWeb) {
      _isLoadingPage = false;
      _openInNewTab();
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) => setState(() => _isLoadingPage = true),
            onPageFinished: (_) => setState(() => _isLoadingPage = false),
          ),
        )
        ..loadRequest(_snapUrl);
    }

    // Poll tiap 4 detik -- cukup responsif tanpa membanjiri backend selagi
    // user isi form pembayaran.
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkStatus());
  }

  Future<void> _openInNewTab() async {
    await launchUrl(_snapUrl, webOnlyWindowName: '_blank');
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus({bool showLoadingIndicator = false}) async {
    if (_closed) return;
    if (showLoadingIndicator) setState(() => _isCheckingStatus = true);

    try {
      final transaction = await ref.read(transaksiRepositoryProvider).getTransactionDetail(widget.transactionId);

      if (!mounted) return;
      if (showLoadingIndicator) setState(() => _isCheckingStatus = false);

      if (transaction.status != TransactionStatus.pending) {
        _finish(transaction.status);
      }
    } catch (_) {
      // Gagal-lembut -- koneksi sempat putus pas polling bukan alasan
      // nutup paksa, coba lagi di tick berikutnya / tombol manual.
      if (mounted && showLoadingIndicator) setState(() => _isCheckingStatus = false);
    }
  }

  void _finish(TransactionStatus status) {
    if (_closed) return;
    _closed = true;
    _pollTimer?.cancel();

    // Refresh riwayat & detail supaya begitu user balik ke layar
    // sebelumnya, datanya sudah status terbaru -- bukan nunggu manual
    // pull-to-refresh.
    ref.invalidate(transaksiNotifierProvider);
    ref.invalidate(transaksiDetailProvider(widget.transactionId));
    ref.invalidate(mySubscriptionNotifierProvider);

    Navigator.of(context).pop(CheckoutResult(transactionId: widget.transactionId, status: status));
  }

  Future<bool> _handleManualClose() async {
    // Cek status sekali lagi pas user coba keluar manual -- jaga-jaga
    // pembayaran sebenarnya sudah selesai tapi tick polling berikutnya
    // belum sempat jalan.
    await _checkStatus();
    return !_closed;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canPop = await _handleManualClose();
        if (canPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        appBar: AppBar(
          backgroundColor: AppColors.neutral50,
          title: const Text('Pembayaran'),
          actions: [
            IconButton(
              tooltip: 'Cek status pembayaran',
              icon: _isCheckingStatus
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: _isCheckingStatus ? null : () => _checkStatus(showLoadingIndicator: true),
            ),
          ],
        ),
        body: kIsWeb ? _WebFallbackBody(onReopen: _openInNewTab) : _buildWebView(),
      ),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoadingPage) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

/// Body khusus web -- WebView asli tidak bisa dipakai, jadi pembayaran
/// dibuka di tab baru dan layar ini cuma menunggu + polling status.
class _WebFallbackBody extends StatelessWidget {
  const _WebFallbackBody({required this.onReopen});
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new, color: AppColors.brand500, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Pembayaran dibuka di tab baru',
              style: TextStyle(color: AppColors.neutral900, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selesaikan pembayaran di tab yang baru terbuka. Halaman ini otomatis lanjut begitu pembayaran terdeteksi selesai.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.neutral500, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onReopen,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Buka Lagi Tab Pembayaran'),
            ),
          ],
        ),
      ),
    );
  }
}

