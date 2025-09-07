// FRP_MDTUI Bullet-Proof Audio Player
// Handles all common FiveM NUI audio issues: paths, codecs, autoplay, errors

class AudioPlayer {
    constructor() {
        this.audioContext = null;
        this.isInitialized = false;
        this.initializeAudioContext();
        this.setupNUIListener();
    }

    // Initialize audio context for better control
    initializeAudioContext() {
        try {
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            console.log('[AudioPlayer] Audio context initialized successfully');
            this.isInitialized = true;
        } catch (error) {
            console.error('[AudioPlayer] Failed to initialize audio context:', error);
            this.isInitialized = false;
        }
    }

    // Setup NUI message listener
    setupNUIListener() {
        window.addEventListener('message', (event) => {
            const data = event.data;
            
            if (data.action === 'playAudio') {
                this.playAudio(data.file, data.volume, data.delay);
            }
        });
    }

    // Build guaranteed-correct NUI URL
    nuiUrlFor(file) {
        const res = GetParentResourceName();
        // Ensure no leading slashes, and encode each path segment to avoid space issues
        const safe = file.split('/').map(encodeURIComponent).join('/');
        return `nui://${res}/web/sounds/${safe}`;
    }

    // Check codec support
    checkCodecSupport() {
        const probe = document.createElement('audio');
        const wavOK = !!probe.canPlayType && probe.canPlayType('audio/wav') !== '';
        const oggOK = !!probe.canPlayType && probe.canPlayType('audio/ogg') !== '';
        return { wavOK, oggOK };
    }

    // Show audio unlock overlay for autoplay issues
    showAudioUnlockOverlay(onUnlock) {
        const overlay = document.getElementById('audio-unlock');
        const button = document.getElementById('audio-unlock-btn');
        
        if (!overlay || !button) {
            console.warn('[AudioPlayer] Audio unlock overlay not found, proceeding anyway');
            return onUnlock && onUnlock();
        }

        overlay.style.display = 'flex';
        
        const finish = () => {
            overlay.style.display = 'none';
            // Play a 10ms silent buffer to "prime" audio
            const a = new Audio('data:audio/wav;base64,UklGRgAAAABXQVZFZm10IBAAAAABAAEAESsAACJWAAACABAAAAABAACAgICAgA==');
            a.play().catch(() => {}).finally(() => onUnlock && onUnlock());
        };
        
        button.onclick = finish;
    }

    // Main audio playback function
    async playAudio(file, volume = 1.0, delay = 0) {
        console.log('[AudioPlayer] Playing audio:', file, 'at volume', volume);
        
        // Resume audio context if suspended
        if (this.audioContext && this.audioContext.state === 'suspended') {
            await this.audioContext.resume();
        }

        // Convert .wav requests to .ogg for new audio files
        let resolvedFile = file;
        if (file.toLowerCase().endsWith('.wav')) {
            resolvedFile = file.replace(/\.wav$/i, '.ogg');
            console.log('[AudioPlayer] Converting .wav to .ogg:', file, '->', resolvedFile);
        }
        
        const resolvedSrc = this.nuiUrlFor(resolvedFile);
        console.log('[AudioPlayer] Resolved URL:', resolvedSrc);

        const audio = new Audio(resolvedSrc);
        audio.volume = Math.min(Math.max(volume, 0), 1);
        audio.preload = 'auto';

        // Attach error listener that logs the actual error code
        let errorHandled = false;
        audio.addEventListener('error', () => {
            if (errorHandled) return;
            errorHandled = true;
            
            const err = audio.error;
            const errorMap = {
                1: 'ABORTED',
                2: 'NETWORK',
                3: 'DECODE',
                4: 'SRC_NOT_SUPPORTED'
            };
            
            console.error('[AudioPlayer] Audio error:', resolvedFile, errorMap[err?.code] || 'unknown', err);
            
            // Notify Lua so the queue doesn't hang
            this.notifyAudioFinished();
        });

        const start = async () => {
            try {
                await audio.play();
                console.log('[AudioPlayer] Started:', resolvedFile);
                
                // Set up completion handler
                audio.onended = () => {
                    console.log('[AudioPlayer] Finished:', resolvedFile);
                    this.notifyAudioFinished();
                };
                
            } catch (e) {
                // Autoplay or a DOMException—surface details
                console.warn('[AudioPlayer] play() rejected:', resolvedFile, e && (e.name || e), e);
                
                if (e && e.name === 'NotAllowedError') {
                    // Show click-to-enable overlay
                    this.showAudioUnlockOverlay(() => start());
                } else {
                    // Network/NotSupported—advance queue to avoid deadlock
                    console.error('[AudioPlayer] Fatal error, advancing queue:', resolvedFile, e);
                    this.notifyAudioFinished();
                }
            }
        };

        // Handle delay
        if (delay > 0) {
            setTimeout(start, delay);
        } else {
            start();
        }
    }

    // Notify Lua that audio finished (success or failure)
    notifyAudioFinished() {
        fetch(`https://${GetParentResourceName()}/audioFinished`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({})
        }).catch(err => console.error('[AudioPlayer] Failed to notify audio finished:', err));
    }

    // Test the audio system
    testAudio() {
        console.log('[AudioPlayer] Testing audio system...');
        
        // Test with a simple beep
        const testSrc = 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSuBzvLZiTYIG2m98OScTgwOUarm7blmGgU7k9n1unEiBC13yO/eizEIHWq+8+OWT';
        
        const audio = new Audio(testSrc);
        audio.volume = 0.3;
        
        audio.onended = () => {
            console.log('[AudioPlayer] Test audio finished');
        };
        
        audio.onerror = (error) => {
            console.error('[AudioPlayer] Test audio error:', error);
        };
        
        audio.play().catch(error => {
            console.error('[AudioPlayer] Failed to play test audio:', error);
        });
    }
}

// Initialize the audio player
const audioPlayer = new AudioPlayer();

// Export for use in other scripts
window.audioPlayer = audioPlayer;
