document.addEventListener('DOMContentLoaded', async () => {
  const apiUrlInput = document.getElementById('apiUrl');
  const pairingCodeInput = document.getElementById('pairingCode');
  const connectBtn = document.getElementById('connectBtn');
  const statusDot = document.getElementById('statusDot');
  const statusText = document.getElementById('statusText');

  // Load saved settings
  const data = await chrome.storage.local.get(['apiUrl', 'pairingCode', 'isConnected']);
  if (data.apiUrl) apiUrlInput.value = data.apiUrl;
  if (data.pairingCode) pairingCodeInput.value = data.pairingCode;
  
  if (data.isConnected) {
    statusDot.classList.add('active');
    statusText.textContent = 'PROTECTED 🟢';
    connectBtn.textContent = 'Disconnect';
    connectBtn.style.background = '#EF4444';
  }

  connectBtn.addEventListener('click', async () => {
    const isConnected = statusDot.classList.contains('active');

    if (isConnected) {
      // Disconnect
      await chrome.storage.local.set({ isConnected: false });
      statusDot.classList.remove('active');
      statusText.textContent = 'Not Connected';
      connectBtn.textContent = 'Connect & Protect';
      connectBtn.style.background = '#2563EB';
      chrome.runtime.sendMessage({ action: 'DISCONNECT' });
    } else {
      const apiUrl = apiUrlInput.value.trim();
      const code = pairingCodeInput.value.trim();

      if (!apiUrl || !code) {
        alert('Please enter both Backend API URL and 6-digit Pairing Code');
        return;
      }

      await chrome.storage.local.set({
        apiUrl: apiUrl,
        pairingCode: code,
        isConnected: true
      });

      statusDot.classList.add('active');
      statusText.textContent = 'PROTECTED 🟢';
      connectBtn.textContent = 'Disconnect';
      connectBtn.style.background = '#EF4444';

      chrome.runtime.sendMessage({ action: 'CONNECT', apiUrl, code });
    }
  });
});
