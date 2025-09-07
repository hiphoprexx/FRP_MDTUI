// ALPR System - Classic Layout with Modern LSPD Theme
class ALPRSystem {
    constructor() {
        this.isOpen = false;
        this.isScanning = false;
        this.isMinimized = false;
        this.detectedPlates = [];
        this.selectedPlate = null;
        this.unitName = '1-LINCOLN-18';
        this.gpsCoords = { x: 0, y: 0, z: 0 };
        this.container = null;
        
        this.initializeNUIListener();
        this.initializeHotkeys();
    }

    initializeNUIListener() {
        window.addEventListener('message', (event) => {
            const data = event.data;
            
            switch (data.action) {
                case 'ALPR_OPEN':
                    this.open(data);
                    break;
                case 'ALPR_CLOSE':
                    this.close();
                    break;
                case 'ALPR_TOGGLE':
                    this.toggleScanning(data.enabled);
                    break;
                case 'ALPR_SCAN':
                    this.onScan(data);
                    break;
                case 'plateDetected':
                    if (data.plateData) this.onScan(data.plateData);
                    break;
                case 'updateScanCount':
                    this.updatePlatesCount();
                    break;
                case 'updateGPS':
                    if (data.coords) {
                        this.gpsCoords = data.coords;
                        this.updateChips && this.updateChips();
                    }
                    break;
                case 'ALPR_CLEAR':
                    this.clearList();
                    break;
                default:
                    console.log('[ALPRSystem] Unknown action:', data.action);
                    break;
            }
        });
    }

    initializeHotkeys() {
        document.addEventListener('keydown', (event) => {
            if (!this.isOpen) return;
            
            // Only process hotkeys when UI is focused (Left ALT)
            if (!document.body.classList.contains('nui-focused')) return;
            
            switch (event.key.toLowerCase()) {
                case 's':
                    event.preventDefault();
                    this.toggleScanning();
                    break;
                case 'escape':
                    event.preventDefault();
                    this.close();
                    break;
            }
        });
    }

    open(data) {
        if (this.isOpen) {
            console.log('[ALPRSystem] ALPR interface already open, ignoring duplicate open');
            return;
        }
        console.log('[ALPRSystem] Opening ALPR interface');
        this.isOpen = true;
        
        if (data.unit) {
            this.unitName = data.unit;
        }

        this.container = document.getElementById('alpr-container');
        if (!this.container) {
            console.error('[ALPRSystem] ALPR container not found');
            return;
        }
        
        // Update unit name
        const unitLabel = document.getElementById('unit-label');
        if (unitLabel) {
            unitLabel.textContent = this.unitName;
        }
        
        // Show container
        this.container.style.display = 'flex';
        this.container.classList.add('interactive');
        
        // Setup event listeners
        this.setupEventListeners();
        
        // Update initial state
        this.updateStatus();
        this.updatePlatesList();
        this.updatePlatesCount();
        this.updateSelectedPlateDisplay();
        this.updateChips && this.updateChips();
        
        console.log('[ALPRSystem] ALPR interface opened successfully');
    }

    close() {
        console.log('[ALPRSystem] Closing ALPR interface');
        this.isOpen = false;
        this.isScanning = false;
        this.isMinimized = false;
        
        if (this.container) {
            this.container.style.display = 'none';
            this.container.classList.remove('interactive', 'minimized');
        }
        
        const minimizedBar = document.getElementById('minimized-bar');
        if (minimizedBar) {
            minimizedBar.style.display = 'none';
        }
        
        // Notify client that ALPR UI closed
        this.sendNui('alprClosed', {});
    }

    setupEventListeners() {
        if (!this.container) return;
        
        // Header controls
        const startStopBtn = document.getElementById('start-stop-btn');
        if (startStopBtn && !startStopBtn.dataset.bound) {
            startStopBtn.dataset.bound = '1';
            startStopBtn.addEventListener('click', () => {
                console.log('[ALPRSystem] START/STOP clicked; current isScanning:', this.isScanning);
                this.toggleScanning();
            });
        }

        const minimizeBtn = document.getElementById('minimize-btn');
        if (minimizeBtn) {
            minimizeBtn.addEventListener('click', () => {
                this.minimizeWindow();
            });
        }

        const closeBtn = document.getElementById('close-btn');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => {
                this.close();
            });
        }

        // Vehicle info button
        const vehicleInfoBtn = document.getElementById('vehicle-info-btn');
        if (vehicleInfoBtn && !vehicleInfoBtn.dataset.bound) {
            vehicleInfoBtn.dataset.bound = '1';
            vehicleInfoBtn.addEventListener('click', () => {
                this.showVehicleInfo();
            });
        }

        // No additional buttons needed for this design

        // Restore button
        const restoreBtn = document.getElementById('restore-btn');
        if (restoreBtn) {
            restoreBtn.addEventListener('click', () => {
                this.restoreWindow();
            });
        }

        // Plate selection
        this.container.addEventListener('click', (e) => {
            if (e.target.closest('.plate-row')) {
                const plateRow = e.target.closest('.plate-row');
                const plateNumber = plateRow.dataset.plate;
                this.selectPlate(plateNumber);
            }
        });

        // Setup drag functionality
        this.setupDragFunctionality();
    }

    setupDragFunctionality() {
        if (!this.container) return;
        
        const header = this.container.querySelector('.alpr-header');
        if (!header) return;
        
        let isDragging = false;
        let dragStart = { x: 0, y: 0 };

        header.addEventListener('mousedown', (e) => {
            isDragging = true;
            dragStart = {
                x: e.clientX - this.getContainerPosition().x,
                y: e.clientY - this.getContainerPosition().y
            };
            e.preventDefault();
        });

        document.addEventListener('mousemove', (e) => {
            if (isDragging) {
                const newX = e.clientX - dragStart.x;
                const newY = e.clientY - dragStart.y;
                
                // Keep window within viewport bounds
                const maxX = window.innerWidth - this.container.offsetWidth;
                const maxY = window.innerHeight - this.container.offsetHeight;
                
                this.container.style.left = Math.max(0, Math.min(newX, maxX)) + 'px';
                this.container.style.top = Math.max(0, Math.min(newY, maxY)) + 'px';
                this.container.style.transform = 'none';
            }
        });

        document.addEventListener('mouseup', () => {
            isDragging = false;
        });
    }

    getContainerPosition() {
        const rect = this.container.getBoundingClientRect();
        return { x: rect.left, y: rect.top };
    }

    minimizeWindow() {
        if (!this.container) return;
        
        this.isMinimized = true;
        this.container.classList.add('minimized');
        this.container.style.display = 'none';
        
        const minimizedBar = document.getElementById('minimized-bar');
        if (minimizedBar) {
            minimizedBar.style.display = 'block';
            this.updateMinimizedStatus();
        }
    }

    restoreWindow() {
        if (!this.container) return;
        
        this.isMinimized = false;
        this.container.classList.remove('minimized');
        this.container.style.display = 'flex';
        
        const minimizedBar = document.getElementById('minimized-bar');
        if (minimizedBar) {
            minimizedBar.style.display = 'none';
        }
    }

    updateMinimizedStatus() {
        const statusDot = document.getElementById('minimized-status-dot');
        const statusText = document.getElementById('minimized-status-text');
        const count = document.getElementById('minimized-count');
        
        if (statusDot) {
            statusDot.className = 'status-dot';
            if (this.isScanning) {
                statusDot.classList.add('scanning');
            }
        }
        
        if (statusText) {
            statusText.textContent = this.isScanning ? 'SCANNING' : 'OFFLINE';
        }
        
        if (count) {
            count.textContent = this.detectedPlates.length;
        }
    }

    toggleScanning(enabled) {
        if (enabled !== undefined) {
            this.isScanning = enabled;
        } else {
            this.isScanning = !this.isScanning;
        }
        
        this.updateStatus();
        this.updateSensorIndicators();
        this.updateMinimizedStatus();
        this.updateChips();
        
        // Send to client (start/stop scanning) — call both legacy and new callbacks for compatibility
        if (this.isScanning) {
            console.log('[ALPRSystem] Requesting client to START scanning');
            this.sendNui('startALPR', {});
            this.sendNui('startALPRScanning', {});
        } else {
            console.log('[ALPRSystem] Requesting client to STOP scanning');
            this.sendNui('stopALPR', {});
            this.sendNui('stopALPRScanning', {});
        }
    }

    updateStatus() {
        const statusDot = document.querySelector('.status-dot');
        const statusText = document.getElementById('status-text');
        const startStopBtn = document.getElementById('start-stop-btn');
        const chipScan = document.getElementById('chip-scan');
        
        if (this.isScanning) {
            statusDot?.classList.add('scanning');
            if (statusText) statusText.textContent = 'SCANNING';
            startStopBtn?.classList.add('active');
            if (startStopBtn) {
                startStopBtn.textContent = 'STOP';
            }
            if (chipScan) { chipScan.textContent = 'SCANNING'; chipScan.classList.add('active'); }
        } else {
            statusDot?.classList.remove('scanning');
            if (statusText) statusText.textContent = 'OFFLINE';
            startStopBtn?.classList.remove('active');
            if (startStopBtn) {
                startStopBtn.textContent = 'START';
            }
            if (chipScan) { chipScan.textContent = 'OFFLINE'; chipScan.classList.remove('active'); }
        }
    }

    updateSensorIndicators() {
        const frontRadar = document.getElementById('front-radar');
        const rearRadar = document.getElementById('rear-radar');
        
        if (this.isScanning) {
            frontRadar?.classList.add('scanning');
            rearRadar?.classList.add('scanning');
        } else {
            frontRadar?.classList.remove('scanning');
            rearRadar?.classList.remove('scanning');
        }
    }

    onScan(data) {
        console.log('[ALPRSystem] Processing scan:', data);
        
        if (!data || !data.plate) {
            console.warn('[ALPRSystem] Invalid scan payload:', data);
            return;
        }

        // Create plate record
        const plateRecord = {
            plate: data.plate.toUpperCase(),
            source: data.source || 'Front',
            flags: data.flags || {},
            seenCount: 1,
            lastSeen: Date.now(),
            vehicle: data.vehicle || {},
            owner: data.owner || '',
            insurance: data.insurance || '',
            expiry: data.expiry || '',
            notes: data.notes || '',
            ...data
        };

        // Check for existing plate (case-insensitive)
        const existingIndex = this.detectedPlates.findIndex(p => 
            p.plate.toUpperCase() === plateRecord.plate.toUpperCase()
        );
        
        if (existingIndex >= 0) {
            // Update existing plate
            const existing = this.detectedPlates[existingIndex];
            this.detectedPlates[existingIndex] = {
                ...existing,
                ...plateRecord,
                seenCount: existing.seenCount + 1,
                lastSeen: Date.now(),
                // Merge flags (OR operation)
                flags: {
                    ...existing.flags,
                    ...plateRecord.flags
                }
            };
            
            // Move to top
            const updatedPlate = this.detectedPlates.splice(existingIndex, 1)[0];
            this.detectedPlates.unshift(updatedPlate);
        } else {
            // Add new plate to beginning
            this.detectedPlates.unshift(plateRecord);
        }

        // Limit to 50 plates
        if (this.detectedPlates.length > 50) {
            this.detectedPlates = this.detectedPlates.slice(0, 50);
        }

        // Update display
        this.updatePlatesList();
        this.updatePlatesCount();
        
        // Auto-select newest plate
        this.selectPlate(plateRecord.plate);
        // Briefly flash the appropriate radar as a hit indicator
        const dotId = (plateRecord.source || 'Front').toLowerCase() === 'rear' ? 'rear-radar' : 'front-radar';
        const dot = document.getElementById(dotId);
        if (dot) {
            dot.classList.add('hit');
            setTimeout(() => dot.classList.remove('hit'), 700);
        }
        // Update front/rear plate previews
        this.renderPlateGlyphsFor(plateRecord.source, plateRecord.plate);
        const opposite = (plateRecord.source || 'front').toLowerCase() === 'rear' ? 'front' : 'rear';
        this.clearPlateGlyphsFor(opposite);
        
        // Check for flags
        this.checkForFlags(plateRecord);
        // Update last seen chip with source and distance if available
        const chipLast = document.getElementById('chip-last');
        if (chipLast) {
            const src = (plateRecord.source || 'Front').toUpperCase();
            const dist = plateRecord.distance !== undefined ? `${plateRecord.distance}m` : '';
            chipLast.textContent = `LAST: ${src} ${dist}`;
        }
    }

    checkForFlags(plateRecord) {
        const flags = [];
        
        if (plateRecord.flags.stolen) flags.push('stolen');
        if (plateRecord.flags.expired) flags.push('expired');
        if (plateRecord.flags.wanted) flags.push('wanted');
        if (plateRecord.flags.uninsured) flags.push('uninsured');
        
        if (flags.length > 0) {
            console.log('[ALPRSystem] Plate has flags:', flags);
            // Could trigger alerts here
        }
    }

    updatePlatesCount() {
        const countElement = document.getElementById('plates-count');
        const chipCount = document.getElementById('chip-count');
        const n = this.detectedPlates.length;
        if (countElement) countElement.textContent = `${n} plates scanned`;
        if (chipCount) chipCount.textContent = `${n} PLATES`;
    }

    // Compact status chips under the header
    updateChips() {
        const chipFront = document.getElementById('chip-front');
        const chipRear = document.getElementById('chip-rear');
        const chipGps = document.getElementById('chip-gps');
        const chipCount = document.getElementById('chip-count');
        const chipScan = document.getElementById('chip-scan');

        if (chipFront) chipFront.classList.add('active');
        if (chipRear) chipRear.classList.add('active');
        if (chipGps && this.gpsCoords) {
            const x = typeof this.gpsCoords.x === 'number' ? this.gpsCoords.x.toFixed(1) : '-';
            const y = typeof this.gpsCoords.y === 'number' ? this.gpsCoords.y.toFixed(1) : '-';
            chipGps.textContent = `GPS: ${x}, ${y}`;
        }
        if (chipCount) chipCount.textContent = `${this.detectedPlates.length} PLATES`;
        if (chipScan) {
            chipScan.textContent = this.isScanning ? 'SCANNING' : 'OFFLINE';
            chipScan.classList.toggle('active', !!this.isScanning);
        }
    }

    updatePlatesList() {
        const platesList = document.getElementById('plates-list');
        if (!platesList) return;
        
        if (this.detectedPlates.length === 0) {
            platesList.innerHTML = `
                <div class="no-plates-message">
                    <div class="no-plates-icon">🚗</div>
                    <div class="no-plates-text">No plates detected</div>
                    <div class="no-plates-subtext">Drive near vehicles to scan</div>
                </div>
            `;
            return;
        }

        platesList.innerHTML = this.detectedPlates.map(plate => {
            const flags = [];
            if (plate.flags.stolen) flags.push('stolen');
            if (plate.flags.expired) flags.push('expired');
            if (plate.flags.wanted) flags.push('wanted');
            if (plate.flags.uninsured) flags.push('uninsured');
            
            const flagsHtml = flags.map(flag => 
                `<span class="plate-flag ${flag}">${flag.toUpperCase()}</span>`
            ).join('');
            
            const isSelected = this.selectedPlate && this.selectedPlate.plate === plate.plate;
            
            return `
                <div class="plate-row ${isSelected ? 'selected' : ''}" data-plate="${plate.plate}">
                    <div class="plate-number">${plate.plate}</div>
                    <div class="plate-source">${plate.source}</div>
                    <div class="plate-flags">${flagsHtml}</div>
                </div>
            `;
        }).join('');
    }

    selectPlate(plateNumber) {
        console.log('[ALPRSystem] Selecting plate:', plateNumber);
        
        const plate = this.detectedPlates.find(p => 
            p.plate.toUpperCase() === plateNumber.toUpperCase()
        );
        
        if (!plate) {
            console.log('[ALPRSystem] Plate not found:', plateNumber);
            return;
        }

        this.selectedPlate = plate;
        this.updateSelectedPlateDisplay(plate);
        this.updatePlatesList(); // Refresh to show selection
    }

    updateSelectedPlateDisplay(plate) {
        console.log('[ALPRSystem] Updating selected plate display:', plate);
        const value = plate && plate.plate ? plate.plate : '';
        // Update overlays
        this.updatePlateText(value);
        // Render only to the correct preview based on source
        if (plate && plate.source) {
            this.renderPlateGlyphsFor(plate.source, value);
            const opposite = plate.source.toLowerCase() === 'rear' ? 'front' : 'rear';
            this.clearPlateGlyphsFor(opposite);
        }
        
        // Enable vehicle info button
        const vehicleInfoBtn = document.getElementById('vehicle-info-btn');
        if (vehicleInfoBtn) {
            vehicleInfoBtn.disabled = false;
        }
    }

    renderPlateGlyphs(plateNumber) {
        const glyphsContainer = document.getElementById('plate-glyphs');
        if (!glyphsContainer) return;
        const safe = (plateNumber || '')
            .toUpperCase()
            .replace(/[^A-Z0-9]/g, '');
        if (safe.length === 0) {
            glyphsContainer.innerHTML = '';
            return;
        }
        const basePath = 'plates/blue_27x55';
        const html = Array.from(safe).map(ch => {
            const name = /[0-9]/.test(ch) ? ch : ch;
            return `<img class="glyph" alt="${ch}" src="${basePath}/${name}.png">`;
        }).join('');
        glyphsContainer.innerHTML = html;
    }

    // Render glyphs into front or rear preview under the list
    renderPlateGlyphsFor(position, plateNumber) {
        const isRear = (position || '').toLowerCase() === 'rear';
        const containerId = isRear ? 'plate-glyphs-rear' : 'plate-glyphs-front';
        const glyphsContainer = document.getElementById(containerId);
        if (!glyphsContainer) return;
        const safe = (plateNumber || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
        const basePath = 'plates/blue_27x55';
        glyphsContainer.innerHTML = Array.from(safe).map(ch => {
            const name = /[0-9]/.test(ch) ? ch : ch;
            return `<img class=\"glyph\" alt=\"${ch}\" src=\"${basePath}/${name}.png\">`;
        }).join('');
    }

    clearPlateGlyphsFor(position) {
        const isRear = (position || '').toLowerCase() === 'rear';
        const containerId = isRear ? 'plate-glyphs-rear' : 'plate-glyphs-front';
        const glyphsContainer = document.getElementById(containerId);
        if (glyphsContainer) {
            glyphsContainer.innerHTML = '';
        }
    }

    updatePlateText(plateNumber) {
        const plateTextElement = document.getElementById('plate-text');
        if (plateTextElement) {
            plateTextElement.textContent = plateNumber || 'NO PLATE';
        }
    }

    updatePlateDetails(plate) {
        const makeElement = document.getElementById('plate-make');
        const modelElement = document.getElementById('plate-model');
        const colorElement = document.getElementById('plate-color');
        const ownerElement = document.getElementById('plate-owner');
        const insuranceElement = document.getElementById('plate-insurance');
        const expiryElement = document.getElementById('plate-expiry');
        const notesElement = document.getElementById('plate-notes');
        
        if (makeElement) makeElement.textContent = plate.vehicle?.make || '—';
        if (modelElement) modelElement.textContent = plate.vehicle?.model || '—';
        if (colorElement) colorElement.textContent = plate.vehicle?.color || '—';
        if (ownerElement) ownerElement.textContent = plate.owner || '—';
        if (insuranceElement) insuranceElement.textContent = plate.insurance || '—';
        if (expiryElement) expiryElement.textContent = plate.expiry || '—';
        if (notesElement) notesElement.textContent = plate.notes || '—';
    }

    updatePlateImage(plate) {
        const plateImage = document.getElementById('selected-plate-image');
        if (!plateImage) return;
        
        // Generate plate image path based on plate number
        const plateImagePath = this.generatePlateImagePath(plate.plate);
        
        if (plateImagePath) {
            plateImage.src = plateImagePath;
            plateImage.style.display = 'block';
        } else {
            plateImage.style.display = 'none';
        }
    }

    clearList() {
        console.log('[ALPRSystem] Clearing all plates');
        this.detectedPlates = [];
        this.selectedPlate = null;
        this.updatePlatesCount();
        this.updatePlatesList();
        this.updatePlateText('');
        this.renderPlateGlyphs('');
        
        // Disable vehicle info button
        const vehicleInfoBtn = document.getElementById('vehicle-info-btn');
        if (vehicleInfoBtn) {
            vehicleInfoBtn.disabled = true;
        }
    }

    showVehicleInfo() {
        if (!this.selectedPlate) {
            console.log('[ALPRSystem] No plate selected for vehicle info');
            return;
        }

        console.log('[ALPRSystem] Showing vehicle info for plate:', this.selectedPlate.plate);

        // Ask client to fetch vehicle info; dispatch screen will display it
        this.sendNui('getVehicleInfo', { plate: this.selectedPlate.plate });
    }

    // Removed old status and control methods - not needed for this design

    sendNui(action, data) {
        const resourceName = GetParentResourceName();
        console.log('[ALPRSystem] Sending NUI callback:', action, data, 'to resource:', resourceName);
        fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify(data)
        }).then(response => {
            console.log('[ALPRSystem] NUI callback response:', action, response.status);
        }).catch(err => {
            console.error('[ALPRSystem] Error posting to Lua:', err);
        });
    }
}

// Helper function to get resource name
function GetParentResourceName() {
    // Ensure NUI callbacks target our resource
    return 'frp_mdtui';
}

// Initialize the ALPR system
const alprSystem = new ALPRSystem();

// Initialize ALPR interface when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    console.log('[ALPRSystem] DOM loaded, initializing ALPR interface');
    
    // Check if ALPR container exists
    const alprContainer = document.getElementById('alpr-container');
    if (alprContainer) {
        console.log('[ALPRSystem] ALPR container found, setting up interface');
        
        // Hide the ALPR interface by default
        alprContainer.style.display = 'none';
        console.log('[ALPRSystem] ALPR interface hidden by default');
    } else {
        console.error('[ALPRSystem] ALPR container not found during initialization');
    }
});

// Event listeners are handled by the ALPRSystem class initializeNUIListener() method

// Handle focus events for hotkeys
document.addEventListener('keydown', (event) => {
    if (event.key === 'AltLeft' || event.key === 'Alt') {
        document.body.classList.add('nui-focused');
    }
});

document.addEventListener('keyup', (event) => {
    if (event.key === 'AltLeft' || event.key === 'Alt') {
        document.body.classList.remove('nui-focused');
    }
});