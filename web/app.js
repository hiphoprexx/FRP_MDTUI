// FRP MDT UI - Professional LSPD Computer Interface
class MDTInterface {
    constructor() {
        this.isOpen = false;
        this.currentPayload = null;
        this.currentRect = { x: 100, y: 100, width: 800, height: 580 };
        this.isDragging = false;
        this.isResizing = false;
        this.dragStart = { x: 0, y: 0 };
        this.resizeStart = { x: 0, y: 0, width: 0, height: 0 };
        this.selectedPriority = null;
        this.audioContext = null;
        this.audioQueue = [];
        this.isPlayingAudio = false;
        
        // Pop-out window properties
        this.popoutWindow = null;
        this.popoutRect = { x: window.innerWidth - 350, y: 50, width: 300, height: 200 };
        this.isPopoutDragging = false;
        this.isPopoutResizing = false;
        this.popoutDragStart = { x: 0, y: 0 };
        this.popoutResizeStart = { x: 0, y: 0, width: 0, height: 0 };
        
        // ALPR window properties
        this.alprWindow = null;
        this.alprRect = { x: 100, y: 100, width: 600, height: 400 };
        this.isAlprDragging = false;
        this.alprDragStart = { x: 0, y: 0 };
        this.alprActive = false;
        this.detectedPlates = [];
        this.selectedPlate = null;
        
        // Ensure UI is hidden by default
        this.ensureUIHidden();
        
        this.initializeEventListeners();
        this.initializePrioritySelection();
        this.initializeAudioSystem();
        this.initializeNUIListener();
        this.initializePopoutWindow();
        this.initializeALPRWindow();
    }

    // Ensure UI is hidden by default
    ensureUIHidden() {
        const container = document.getElementById('mdt-container');
        if (container) {
            container.style.display = 'none';
            console.log('[MDTInterface] UI hidden by default');
        } else {
            console.log('[MDTInterface] Container not found during initialization');
        }
    }

    initializeEventListeners() {
        // Close button with debounce - closes main UI but keeps dispatch popup if open
        let closeButtonDebounce = false;
        document.getElementById('close-button').addEventListener('click', () => {
            if (closeButtonDebounce) {
                console.log('[MDTInterface] Close button click ignored (debounced)');
                return;
            }
            closeButtonDebounce = true;
            this.closeMainUI();
            // Reset debounce after 500ms
            setTimeout(() => {
                closeButtonDebounce = false;
            }, 500);
        });

        // Pop-out button
        document.getElementById('popout-button').addEventListener('click', () => {
            this.togglePopoutWindow();
        });

        // Refresh incidents button
        document.getElementById('refresh-incidents').addEventListener('click', () => {
            this.refreshIncidents();
        });

        // ALPR button removed - now handled by tab

        // Toolbar buttons
        document.querySelectorAll('.toolbar-button').forEach(button => {
            button.addEventListener('click', (e) => {
                this.handleToolbarClick(e);
            });
        });

        // Tab buttons
        document.querySelectorAll('.tab-button').forEach(tab => {
            tab.addEventListener('click', (e) => {
                this.handleTabClick(e);
            });
        });

        // Status dropdown
        document.getElementById('status-dropdown').addEventListener('change', (e) => {
            this.handleStatusChange(e);
        });

        // Priority badges
        document.querySelectorAll('.priority-badge').forEach(badge => {
            badge.addEventListener('click', (e) => {
                this.handlePriorityClick(e);
            });
        });

        // Drag and resize functionality
        this.setupDragAndResize();
    }

    initializePrioritySelection() {
        // Set default priority to Code 2 (yellow)
        this.selectPriority('Code 2');
    }

    handlePriorityClick(event) {
        const badge = event.currentTarget;
        const priority = badge.dataset.priority;
        this.selectPriority(priority);
    }

    selectPriority(priority) {
        // Remove previous selection
        document.querySelectorAll('.priority-badge').forEach(badge => {
            badge.classList.remove('selected');
        });

        // Add selection to new priority
        const selectedBadge = document.querySelector(`[data-priority="${priority}"]`);
        if (selectedBadge) {
            selectedBadge.classList.add('selected');
            this.selectedPriority = priority;
        }
    }

    handleToolbarClick(event) {
        const button = event.currentTarget;
        const status = button.dataset.status;

        // Handle special cases
        if (status === 'Panic') {
            this.handlePanic();
            return;
        }

        if (status === 'ALPR') {
            this.handleALPR();
            return;
        }

        if (status === 'Settings') {
            this.handleSettings();
            return;
        }

        if (status === 'TestAudio') {
            this.handleTestAudio();
            return;
        }

        // Update status dropdown
        document.getElementById('status-dropdown').value = status;

        // Update active state
        document.querySelectorAll('.toolbar-button').forEach(btn => {
            btn.classList.remove('active');
        });
        button.classList.add('active');

        // Send status update to Lua
        this.postToLua('statusUpdate', { status: status });
    }

    handlePanic() {
        const container = document.getElementById('mdt-container');
        container.classList.toggle('emergency');
        
        // Send panic alert
        this.postToLua('panic', { active: container.classList.contains('emergency') });
    }

    handleALPR() {
        console.log('[MDTInterface] ALPR button clicked, opening dedicated ALPR interface');
        
        // Open the dedicated ALPR interface
        this.openDedicatedALPR();
        
        // Update button state
        const alprButton = document.querySelector('[data-status="ALPR"]');
        alprButton.classList.add('active');
    }

    handleSettings() {
        // Open settings modal or toggle settings mode
        this.postToLua('settings', { action: 'open' });
    }

    handleTestAudio() {
        console.log('Test Audio button clicked');
        
        // Test with a sample audio file
        const testAudioFile = 'AREAS/AREA_DOWNTOWN_01.wav';
        console.log('Testing audio with:', testAudioFile);
        
        // Test HTML5 audio playback
        this.playAudio(testAudioFile, 0.5);
        
        // Also send a test message to the Lua client
        fetch(`https://${GetParentResourceName()}/testAudio`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify({
                audioFile: testAudioFile,
                volume: 0.5
            })
        }).catch(err => console.log('Error testing audio:', err));
    }

    handleStatusChange(event) {
        const status = event.target.value;
        
        // Update toolbar button states
        document.querySelectorAll('.toolbar-button').forEach(btn => {
            btn.classList.remove('active');
            if (btn.dataset.status === status) {
                btn.classList.add('active');
            }
        });

        // Send status update to Lua
        this.postToLua('statusUpdate', { status: status });
    }

    handleTabClick(event) {
        const tab = event.currentTarget;
        const tabName = tab.dataset.tab;

        // Update active tab
        document.querySelectorAll('.tab-button').forEach(btn => {
            btn.classList.remove('active');
        });
        tab.classList.add('active');

        // Switch tab content
        this.switchTab(tabName);
    }

    switchTab(tabName) {
        // Special-case ALPR: keep the current tab visible and just open the overlay
        if (tabName === 'alpr') {
            console.log('[MDTInterface] ALPR tab clicked, opening dedicated ALPR interface');
            this.openDedicatedALPR();
            return;
        }
        
        // Special-case ASE: keep the current tab visible and just open the overlay
        if (tabName === 'ase') {
            console.log('[MDTInterface] ASE tab clicked, opening dedicated ASE interface');
            this.openDedicatedASE();
            return;
        }

        // Hide all tab contents first
        document.getElementById('incident-tab').style.display = 'none';
        document.getElementById('incidents-tab').style.display = 'none';

        // Show the selected tab content
        switch (tabName) {
            case 'incident':
                document.getElementById('incident-tab').style.display = 'block';
                if (this.currentPayload) {
                    this.updateDetailsDisplay(this.currentPayload.details);
                } else {
                    this.showNoCalloutMessage();
                }
                break;
            case 'incidents':
                document.getElementById('incidents-tab').style.display = 'block';
                this.showIncidentsTab();
                break;
            case 'peds':
                document.getElementById('incident-tab').style.display = 'block';
                document.getElementById('details-content').innerHTML = '<div class="tab-content">Pedestrian Database</div>';
                break;
            case 'vehicles':
                document.getElementById('incident-tab').style.display = 'block';
                document.getElementById('details-content').innerHTML = '<div class="tab-content">Vehicle Database</div>';
                break;
        }
    }

    showIncidentsTab() {
        console.log('[MDTInterface] Showing incidents tab');
        
        // Request active incidents from server
        this.postToLua('getActiveIncidents', {});
    }

    refreshIncidents() {
        this.postToLua('getActiveIncidents', {});
    }

    populateIncidentsTable(incidents) {
        const tbody = document.getElementById('incidents-table-body');
        
        if (!incidents || incidents.length === 0) {
            tbody.innerHTML = `
                <tr class="no-incidents-row">
                    <td colspan="5">
                        <div class="no-incidents">
                            <div class="no-incidents-icon">📋</div>
                            <div class="no-incidents-text">No Active Incidents</div>
                            <div class="no-incidents-subtext">All incidents have been resolved</div>
                        </div>
                    </td>
                </tr>
            `;
            return;
        }

        tbody.innerHTML = incidents.map(incident => {
            const codeClass = incident.priority ? incident.priority.toLowerCase().replace(' ', '-') : 'code-1';
            const lastUpdate = incident.lastUpdate || new Date().toLocaleString();
            
            return `
                <tr class="incident-row" data-incident-id="${incident.id}">
                    <td class="incident-description">${incident.description || 'Unknown Incident'}</td>
                    <td><span class="incident-code ${codeClass}">${incident.priority || 'Code 1'}</span></td>
                    <td class="incident-unit">${incident.unit || 'N/A'}</td>
                    <td class="incident-time">${lastUpdate}</td>
                    <td class="incident-actions">
                        <button class="incident-action-btn attach" onclick="mdtInterface.attachToIncident('${incident.id}')">Attach</button>
                        <button class="incident-action-btn close" onclick="mdtInterface.closeIncident('${incident.id}')">Close</button>
                    </td>
                </tr>
            `;
        }).join('');

        // Add click handlers for row selection
        tbody.querySelectorAll('.incident-row').forEach(row => {
            row.addEventListener('click', (e) => {
                if (!e.target.classList.contains('incident-action-btn')) {
                    this.selectIncidentRow(row);
                }
            });
        });
    }

    selectIncidentRow(row) {
        // Remove previous selection
        document.querySelectorAll('.incident-row').forEach(r => r.classList.remove('selected'));
        
        // Add selection to clicked row
        row.classList.add('selected');
        
        // Get incident data and switch to incident tab
        const incidentId = row.dataset.incidentId;
        console.log('[MDTInterface] Selected incident:', incidentId);
        
        // Switch back to incident tab to show details
        this.switchTab('incident');
    }

    attachToIncident(incidentId) {
        console.log('[MDTInterface] Attaching to incident:', incidentId);
        this.postToLua('attachToIncident', { incidentId: incidentId });
    }

    closeIncident(incidentId) {
        console.log('[MDTInterface] Closing incident:', incidentId);
        this.postToLua('closeIncident', { incidentId: incidentId });
    }

    flashPriorityButton(priority) {
        console.log('[MDTInterface] Flashing priority button:', priority);
        
        // Find the priority badge
        const badge = document.querySelector(`[data-priority="${priority}"]`);
        if (badge) {
            // Add flashing animation
            badge.classList.add('flashing');
            
            // Remove flashing after 5 seconds
            setTimeout(() => {
                badge.classList.remove('flashing');
            }, 5000);
        }
    }

    setupDragAndResize() {
        const container = document.getElementById('mdt-container');
        const resizeHandle = document.querySelector('.mdt-resize-handle');

        // Mouse down events
        container.addEventListener('mousedown', (e) => {
            if (e.target === container || e.target.classList.contains('mdt-header')) {
                this.startDrag(e);
            }
        });

        resizeHandle.addEventListener('mousedown', (e) => {
            this.startResize(e);
        });

        // Mouse move and up events
        document.addEventListener('mousemove', (e) => {
            if (this.isDragging) {
                this.handleDrag(e);
            } else if (this.isResizing) {
                this.handleResize(e);
            }
        });

        document.addEventListener('mouseup', () => {
            if (this.isDragging || this.isResizing) {
                this.stopDragResize();
            }
        });
    }

    startDrag(e) {
        this.isDragging = true;
        this.dragStart = {
            x: e.clientX - this.currentRect.x,
            y: e.clientY - this.currentRect.y
        };
        e.preventDefault();
    }

    startResize(e) {
        this.isResizing = true;
        this.resizeStart = {
            x: e.clientX,
            y: e.clientY,
            width: this.currentRect.width,
            height: this.currentRect.height
        };
        e.preventDefault();
    }

    handleDrag(e) {
        this.currentRect.x = e.clientX - this.dragStart.x;
        this.currentRect.y = e.clientY - this.dragStart.y;
        this.updatePosition();
    }

    handleResize(e) {
        const deltaX = e.clientX - this.resizeStart.x;
        const deltaY = e.clientY - this.resizeStart.y;
        
        this.currentRect.width = Math.max(600, this.resizeStart.width + deltaX);
        this.currentRect.height = Math.max(400, this.resizeStart.height + deltaY);
        this.updateSize();
    }

    stopDragResize() {
        this.isDragging = false;
        this.isResizing = false;
        this.savePosition();
    }

    updatePosition() {
        const container = document.getElementById('mdt-container');
        container.style.left = this.currentRect.x + 'px';
        container.style.top = this.currentRect.y + 'px';
    }

    updateSize() {
        const container = document.getElementById('mdt-container');
        container.style.width = this.currentRect.width + 'px';
        container.style.height = this.currentRect.height + 'px';
    }

    savePosition() {
        this.postToLua('saveRect', { rect: this.currentRect });
    }

    // Message handling from Lua
    handleMessage(data) {
        console.log('[MDTInterface] Received message:', data);
        switch (data.action) {
            case 'open':
                this.open(data);
                break;
            case 'update':
                this.update(data);
                break;
            case 'close':
                this.close();
                break;
            case 'closeMainUI':
                this.closeMainUI();
                break;
            case 'reopenMainUI':
                this.reopenMainUI();
                break;
            case 'enableDragResize':
                this.enableInteraction();
                break;
            case 'disableDragResize':
                this.disableInteraction();
                break;
            case 'flashPriority':
                this.flashPriorityButton(data.priority);
                break;
            case 'updateOfficerInfo':
                this.updateOfficerInfo(data.callsign, data.rank);
                break;
            case 'updateIncidents':
                this.populateIncidentsTable(data.incidents);
                break;
            case 'plateDetected':
                this.addDetectedPlate(data.plateData);
                break;
            case 'vehicleInfo':
                this.updateVehicleInfo(data.vehicleData);
                break;
            case 'boloAlert':
                this.showBOLOAlert(data.plateData);
                break;
            case 'displayVehicleInfoInDispatch':
                this.displayVehicleInfoInDispatch(data.vehicleData);
                break;
            default:
                console.log('[MDTInterface] Unknown action:', data.action);
                break;
        }
    }

    open(data) {
        console.log('[MDTInterface] Opening UI with data:', data);
        this.isOpen = true;
        this.currentPayload = data.payload || null;
        
        if (data.rect) {
            this.currentRect = data.rect;
        }

        const container = document.getElementById('mdt-container');
        if (container) {
            container.style.display = 'block';
            console.log('[MDTInterface] Container display set to block');
            this.updatePosition();
            this.updateSize();
        } else {
            console.error('[MDTInterface] Container not found when trying to open!');
        }

        // Hide any dispatch displays when reopening full interface
        const minimalDisplay = document.getElementById('minimal-dispatch-display');
        if (minimalDisplay) {
            minimalDisplay.style.display = 'none';
        }
        
        const simpleDisplay = document.getElementById('simple-dispatch-display');
        if (simpleDisplay) {
            simpleDisplay.remove();
        }

        // Restore interactivity to any existing dispatch info
        this.restoreDispatchInteractivity();

        // Update officer info with callsign and rank
        if (data.callsign && data.rank) {
            this.updateOfficerInfo(data.callsign, data.rank);
        } else if (data.payload && data.payload.unit) {
            this.updateOfficerInfo(data.payload.unit);
        }

        if (this.currentPayload) {
            this.updateDisplay(this.currentPayload);
        } else {
            this.showNoCalloutMessage();
        }
    }

    restoreDispatchInteractivity() {
        // Hide minimal dispatch display when main UI reopens
        const minimalDisplay = document.getElementById('minimal-dispatch-display');
        if (minimalDisplay) {
            minimalDisplay.style.display = 'none';
        }
        
        // Restore interactivity to popout window if it exists
        const dispatchInfo = document.getElementById('popout-window');
        if (dispatchInfo) {
            // Remove non-interactive styling
            dispatchInfo.style.pointerEvents = 'auto';
            dispatchInfo.style.opacity = '1';
            dispatchInfo.style.cursor = 'default';
            
            // Re-enable all interactive elements
            const interactiveElements = dispatchInfo.querySelectorAll('button, input, select, textarea, [onclick], [tabindex]');
            interactiveElements.forEach(el => {
                el.style.pointerEvents = 'auto';
                el.style.opacity = '1';
                el.disabled = false;
            });
            
            // Remove non-interactive overlay
            const overlay = dispatchInfo.querySelector('.non-interactive-overlay');
            if (overlay) {
                overlay.remove();
            }
        }
    }

    update(data) {
        if (data.payload) {
            this.currentPayload = data.payload;
            this.updateDisplay(data.payload);
        }
    }

    close() {
        // Prevent multiple close calls
        if (!this.isOpen) {
            console.log('[MDTInterface] Close called but UI is already closed, ignoring');
            return;
        }
        
        console.log('[MDTInterface] Closing UI...');
        this.isOpen = false;
        document.getElementById('mdt-container').style.display = 'none';
        
        // Hide cursor and release focus
        this.postToLua('close', {});
        
        // Also close popout window if open
        if (this.popoutWindow && this.popoutWindow.style.display !== 'none') {
            this.closePopoutWindow();
        }
    }

    closeMainUI() {
        console.log('[MDTInterface] Closing main UI but keeping dispatch popup if open...');
        
        // Hide the main computer interface
        const mainInterface = document.getElementById('mdt-container');
        if (mainInterface) {
            mainInterface.style.display = 'none';
        }
        
        // Check if dispatch popup is already open
        const dispatchPopup = document.getElementById('popout-window');
        if (dispatchPopup && dispatchPopup.style.display !== 'none') {
            // Dispatch popup is open, keep it visible but make it non-interactive
            this.makeDispatchNonInteractive(dispatchPopup);
            // Send a special callback to remove NUI focus without closing everything
            this.postToLua('removeFocus', {});
            console.log('[MDTInterface] Main UI closed, dispatch popup remains visible but non-interactive');
        } else {
            // No dispatch popup open, close everything
            this.close();
            console.log('[MDTInterface] Main UI closed, no dispatch popup to keep');
        }
    }

    reopenMainUI() {
        console.log('[MDTInterface] Reopening main UI...');
        
        // Show the main computer interface
        const mainInterface = document.getElementById('mdt-container');
        if (mainInterface) {
            mainInterface.style.display = 'block';
        }
        
        // Restore interactivity to dispatch popup if it exists
        const dispatchPopup = document.getElementById('popout-window');
        if (dispatchPopup && dispatchPopup.style.display !== 'none') {
            this.restoreDispatchInteractivity();
            console.log('[MDTInterface] Main UI reopened, dispatch popup restored to interactive');
        }
        
        console.log('[MDTInterface] Main UI reopened successfully');
    }

    createSimpleDispatchDisplay() {
        // Remove any existing minimal display
        const existingDisplay = document.getElementById('simple-dispatch-display');
        if (existingDisplay) {
            existingDisplay.remove();
        }
        
        // Create a new simple dispatch display
        const simpleDisplay = document.createElement('div');
        simpleDisplay.id = 'simple-dispatch-display';
        simpleDisplay.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            width: 300px;
            background: rgba(0, 0, 0, 0.9);
            border: 2px solid #00ff00;
            border-radius: 8px;
            padding: 15px;
            color: #00ff00;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            z-index: 9999;
            box-shadow: 0 0 20px rgba(0, 255, 0, 0.3);
            pointer-events: none;
            user-select: none;
            -webkit-user-select: none;
            -moz-user-select: none;
            -ms-user-select: none;
        `;
        
        // Update content with current dispatch info
        if (this.currentPayload) {
            simpleDisplay.innerHTML = `
                <div style="text-align: center; margin-bottom: 10px;">
                    <strong>DISPATCH INFO</strong>
                </div>
                <div><strong>Location:</strong> ${this.currentPayload.address || 'N/A'}</div>
                <div><strong>Priority:</strong> ${this.currentPayload.priority || 'N/A'}</div>
                <div><strong>Status:</strong> ${this.currentPayload.status || 'N/A'}</div>
                <div><strong>Unit:</strong> ${this.currentPayload.unit || 'N/A'}</div>
                <div style="margin-top: 10px; font-size: 12px; color: #888;">
                    Press /computer to reopen full interface
                </div>
            `;
        } else {
            simpleDisplay.innerHTML = `
                <div style="text-align: center;">
                    <strong>NO ACTIVE DISPATCH</strong>
                </div>
                <div style="margin-top: 10px; font-size: 12px; color: #888;">
                    Press /computer to open interface
                </div>
            `;
        }
        
        document.body.appendChild(simpleDisplay);
    }

    makeDispatchNonInteractive(element) {
        // Disable all interactive elements in the dispatch info
        const interactiveElements = element.querySelectorAll('button, input, select, textarea, [onclick], [tabindex]');
        interactiveElements.forEach(el => {
            el.style.pointerEvents = 'none';
            el.style.opacity = '0.7';
            el.disabled = true;
            el.tabIndex = -1;
            // Remove focus if element has it
            if (el.blur) {
                el.blur();
            }
        });
        
        // Make the entire element completely non-interactive
        element.style.pointerEvents = 'none';
        element.style.opacity = '0.8';
        element.style.cursor = 'none';
        element.style.userSelect = 'none';
        element.tabIndex = -1;
        element.style.outline = 'none';
        
        // Remove any existing focus
        if (element.blur) {
            element.blur();
        }
        
        // Force remove focus from document
        if (document.activeElement && document.activeElement.blur) {
            document.activeElement.blur();
        }
        
        // Prevent any mouse events
        element.addEventListener('mousedown', function(e) {
            e.preventDefault();
            e.stopPropagation();
        });
        
        element.addEventListener('mouseup', function(e) {
            e.preventDefault();
            e.stopPropagation();
        });
        
        element.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
        });
        
        // Prevent any keyboard events
        element.addEventListener('keydown', function(e) {
            e.preventDefault();
            e.stopPropagation();
        });
        
        element.addEventListener('keyup', function(e) {
            e.preventDefault();
            e.stopPropagation();
        });
        
        // Prevent focus events
        element.addEventListener('focus', function(e) {
            e.preventDefault();
            e.stopPropagation();
            element.blur();
        });
        
        // Add a subtle overlay to indicate non-interactive state
        let overlay = element.querySelector('.non-interactive-overlay');
        if (!overlay) {
            overlay = document.createElement('div');
            overlay.className = 'non-interactive-overlay';
            overlay.style.cssText = `
                position: absolute;
                top: 0;
                left: 0;
                right: 0;
                bottom: 0;
                background: rgba(0, 0, 0, 0.1);
                pointer-events: none;
                z-index: 1;
                cursor: none;
            `;
            element.style.position = 'relative';
            element.appendChild(overlay);
        }
    }

    createMinimalDispatchDisplay() {
        // Create a minimal dispatch info display that stays on screen
        let minimalDisplay = document.getElementById('minimal-dispatch-display');
        
        if (!minimalDisplay) {
            minimalDisplay = document.createElement('div');
            minimalDisplay.id = 'minimal-dispatch-display';
            minimalDisplay.style.cssText = `
                position: fixed;
                top: 20px;
                right: 20px;
                width: 300px;
                background: rgba(0, 0, 0, 0.9);
                border: 2px solid #00ff00;
                border-radius: 8px;
                padding: 15px;
                color: #00ff00;
                font-family: 'Courier New', monospace;
                font-size: 14px;
                z-index: 9999;
                box-shadow: 0 0 20px rgba(0, 255, 0, 0.3);
                pointer-events: none !important;
                cursor: default !important;
                opacity: 0.8;
                user-select: none;
                -webkit-user-select: none;
                -moz-user-select: none;
                -ms-user-select: none;
            `;
            document.body.appendChild(minimalDisplay);
        }
        
        // Update content with current dispatch info
        if (this.currentPayload) {
            minimalDisplay.innerHTML = `
                <div style="text-align: center; margin-bottom: 10px;">
                    <strong>DISPATCH INFO</strong>
                </div>
                <div><strong>Location:</strong> ${this.currentPayload.address || 'N/A'}</div>
                <div><strong>Priority:</strong> ${this.currentPayload.priority || 'N/A'}</div>
                <div><strong>Status:</strong> ${this.currentPayload.status || 'N/A'}</div>
                <div><strong>Unit:</strong> ${this.currentPayload.unit || 'N/A'}</div>
                <div style="margin-top: 10px; font-size: 12px; color: #888;">
                    Press /computer to reopen full interface
                </div>
            `;
        } else {
            minimalDisplay.innerHTML = `
                <div style="text-align: center;">
                    <strong>NO ACTIVE DISPATCH</strong>
                </div>
                <div style="margin-top: 10px; font-size: 12px; color: #888;">
                    Press /computer to open interface
                </div>
            `;
        }
        
        minimalDisplay.style.display = 'block';
    }

    updateDisplay(payload) {
        // Update input fields
        if (payload.address) document.getElementById('address-input').value = payload.address;
        if (payload.area) document.getElementById('area-input').value = payload.area;
        if (payload.county) document.getElementById('county-input').value = payload.county;
        if (payload.agency) document.getElementById('agency-input').value = payload.agency;
        
        // Update priority if provided
        if (payload.priority) {
            this.selectPriority(payload.priority);
        }

        // Update details
        if (payload.details) {
            this.updateDetailsDisplay(payload.details);
        }

        // Update officer info
        if (payload.unit) {
            this.updateOfficerInfo(payload.unit);
        }

        // Update pop-out window if it's open
        if (this.popoutWindow && this.popoutWindow.style.display !== 'none') {
            this.updatePopoutContent();
        }
    }

    updateDetailsDisplay(details) {
        const detailsContent = document.getElementById('details-content');
        
        if (Array.isArray(details)) {
            const formattedDetails = details.map(detail => `<div class="detail-line">${detail}</div>`).join('');
            detailsContent.innerHTML = formattedDetails;
        } else {
            detailsContent.innerHTML = `<div class="detail-line">${details}</div>`;
        }

        // Add update animation
        detailsContent.classList.add('updating');
        setTimeout(() => {
            detailsContent.classList.remove('updating');
        }, 500);
    }

    updateOfficerInfo(callsign, rank) {
        // Handle direct callsign and rank parameters
        if (callsign && rank) {
            document.getElementById('officer-rank').textContent = rank;
            document.getElementById('officer-callsign').textContent = callsign;
            return;
        }
        
        // Fallback: Parse unit string (e.g., "Sergeant I-Ryan-6")
        if (typeof callsign === 'string' && callsign.includes('-')) {
            const parts = callsign.split('-');
            if (parts.length >= 2) {
                const parsedRank = parts[0];
                const parsedCallsign = parts.slice(1).join('-');
                
                document.getElementById('officer-rank').textContent = parsedRank;
                document.getElementById('officer-callsign').textContent = parsedCallsign;
            }
        }
    }

    showNoCalloutMessage() {
        const detailsContent = document.getElementById('details-content');
        detailsContent.innerHTML = `
            <div class="no-callout-message">
                <div class="no-callout-icon">📋</div>
                <div class="no-callout-text">No Active 911 Call</div>
                <div class="no-callout-subtext">Monitor for incoming 911 calls and dispatch alerts</div>
            </div>
        `;
    }

    enableInteraction() {
        document.getElementById('mdt-container').classList.add('interactive');
    }

    disableInteraction() {
        document.getElementById('mdt-container').classList.remove('interactive');
    }

    postToLua(action, data) {
        // Use the correct resource name for NUI callbacks
        const resourceName = 'frp_mdtui';
        console.log('[MDTInterface] Sending NUI callback:', action, data, 'to resource:', resourceName);
        fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify(data)
        }).then(response => {
            console.log('[MDTInterface] NUI callback response:', action, response.status);
        }).catch(err => console.log('Error posting to Lua:', err));
    }

    // Initialize HTML5 audio system
    initializeAudioSystem() {
        try {
            // Create audio context for better audio control
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            console.log('Audio system initialized successfully');
        } catch (error) {
            console.error('Failed to initialize audio context:', error);
            // Fallback to basic audio
            this.audioContext = null;
        }
    }

    // Initialize NUI message listener
    initializeNUIListener() {
        window.addEventListener('message', (event) => {
            const data = event.data;
            
            switch (data.action) {
                // playAudio is handled by the dedicated audio player
                case 'testAudio':
                    this.testAudio(data.message);
                    break;
                default:
                    // Forward all other actions to the main handleMessage function
                    this.handleMessage(data);
            }
        });
    }

    initializePopoutWindow() {
        this.popoutWindow = document.getElementById('popout-window');
        
        // Pop-out window controls
        document.getElementById('popout-close').addEventListener('click', () => {
            this.closePopoutWindow();
        });

        document.getElementById('popout-minimize').addEventListener('click', () => {
            this.minimizePopoutWindow();
        });

        // Pop-out window drag and resize
        this.setupPopoutDragAndResize();
    }

    setupPopoutDragAndResize() {
        const popoutHeader = this.popoutWindow.querySelector('.popout-header');
        const popoutResizeHandle = this.popoutWindow.querySelector('.popout-resize-handle');

        // Mouse down events
        popoutHeader.addEventListener('mousedown', (e) => {
            this.startPopoutDrag(e);
        });

        popoutResizeHandle.addEventListener('mousedown', (e) => {
            this.startPopoutResize(e);
        });

        // Mouse move and up events
        document.addEventListener('mousemove', (e) => {
            if (this.isPopoutDragging) {
                this.handlePopoutDrag(e);
            } else if (this.isPopoutResizing) {
                this.handlePopoutResize(e);
            }
        });

        document.addEventListener('mouseup', () => {
            if (this.isPopoutDragging || this.isPopoutResizing) {
                this.stopPopoutDragResize();
            }
        });
    }

    togglePopoutWindow() {
        if (this.popoutWindow.style.display === 'none') {
            this.openPopoutWindow();
        } else {
            this.closePopoutWindow();
        }
    }

    openPopoutWindow() {
        this.popoutWindow.style.display = 'block';
        this.updatePopoutPosition();
        this.updatePopoutContent();
        console.log('[MDTInterface] Pop-out window opened');
    }

    closePopoutWindow() {
        this.popoutWindow.style.display = 'none';
        console.log('[MDTInterface] Pop-out window closed');
    }

    minimizePopoutWindow() {
        this.popoutWindow.classList.toggle('minimized');
    }

    updatePopoutContent() {
        if (!this.currentPayload) {
            document.getElementById('popout-location').textContent = 'No Active Call';
            document.getElementById('popout-priority').textContent = 'None';
            document.getElementById('popout-priority').removeAttribute('data-priority');
            document.getElementById('popout-status').textContent = 'Available';
            document.getElementById('popout-unit').textContent = 'N/A';
            
            const detailsElement = document.getElementById('popout-details');
            detailsElement.innerHTML = `
                <div class="no-callout-message">
                    <div class="no-callout-icon">📋</div>
                    <div class="no-callout-text">No Active 911 Call</div>
                </div>
            `;
            return;
        }

        // Update pop-out content with current payload
        document.getElementById('popout-location').textContent = this.currentPayload.address || 'Unknown Location';
        
        const priorityElement = document.getElementById('popout-priority');
        priorityElement.textContent = this.currentPayload.priority || 'None';
        priorityElement.setAttribute('data-priority', this.currentPayload.priority || 'None');
        
        document.getElementById('popout-status').textContent = this.currentPayload.status || 'Available';
        document.getElementById('popout-unit').textContent = this.currentPayload.unit || 'N/A';

        // Update details
        const detailsElement = document.getElementById('popout-details');
        if (this.currentPayload.details && Array.isArray(this.currentPayload.details)) {
            const formattedDetails = this.currentPayload.details.map(detail => 
                `<div class="detail-line">${detail}</div>`
            ).join('');
            detailsElement.innerHTML = formattedDetails;
        } else {
            detailsElement.innerHTML = `
                <div class="no-callout-message">
                    <div class="no-callout-icon">📋</div>
                    <div class="no-callout-text">No Details Available</div>
                </div>
            `;
        }
    }

    startPopoutDrag(e) {
        this.isPopoutDragging = true;
        this.popoutDragStart = {
            x: e.clientX - this.popoutRect.x,
            y: e.clientY - this.popoutRect.y
        };
        e.preventDefault();
    }

    startPopoutResize(e) {
        this.isPopoutResizing = true;
        this.popoutResizeStart = {
            x: e.clientX,
            y: e.clientY,
            width: this.popoutRect.width,
            height: this.popoutRect.height
        };
        e.preventDefault();
    }

    handlePopoutDrag(e) {
        this.popoutRect.x = e.clientX - this.popoutDragStart.x;
        this.popoutRect.y = e.clientY - this.popoutDragStart.y;
        this.updatePopoutPosition();
    }

    handlePopoutResize(e) {
        const deltaX = e.clientX - this.popoutResizeStart.x;
        const deltaY = e.clientY - this.popoutResizeStart.y;
        
        this.popoutRect.width = Math.max(250, this.popoutResizeStart.width + deltaX);
        this.popoutRect.height = Math.max(150, this.popoutResizeStart.height + deltaY);
        this.updatePopoutSize();
    }

    stopPopoutDragResize() {
        this.isPopoutDragging = false;
        this.isPopoutResizing = false;
    }

    updatePopoutPosition() {
        this.popoutWindow.style.left = this.popoutRect.x + 'px';
        this.popoutWindow.style.top = this.popoutRect.y + 'px';
    }

    updatePopoutSize() {
        this.popoutWindow.style.width = this.popoutRect.width + 'px';
        this.popoutWindow.style.height = this.popoutRect.height + 'px';
    }

    initializeALPRWindow() {
        this.alprWindow = document.getElementById('alpr-window');
        // Ensure vehicle info modal is hidden initially
        const vim = document.getElementById('vehicle-info-modal');
        if (vim) vim.style.display = 'none';
        
        // Set up vehicle interface image with multiple path attempts
        const vehicleImage = document.getElementById('vehicle-interface-img');
        if (vehicleImage) {
            this.setVehicleImageSource(vehicleImage);
        }
        
        // ALPR window controls
        document.getElementById('alpr-close').addEventListener('click', () => {
            this.closeALPRWindow();
        });

        document.getElementById('alpr-minimize').addEventListener('click', () => {
            this.minimizeALPRWindow();
        });

        document.getElementById('alpr-toggle').addEventListener('click', () => {
            console.log('[MDTInterface] ALPR toggle button clicked');
            this.toggleALPRSystem();
        });

        document.getElementById('plate-info-btn').addEventListener('click', () => {
            this.showPlateInfo();
        });

        document.getElementById('modal-close').addEventListener('click', () => {
            this.closePlateInfoModal();
        });

        // ALPR window drag and resize
        this.setupALPRDragAndResize();
    }

    setupALPRDragAndResize() {
        const alprHeader = this.alprWindow.querySelector('.alpr-header');

        // Mouse down events
        alprHeader.addEventListener('mousedown', (e) => {
            this.startALPRDrag(e);
        });

        // Resize functionality removed - window is now fixed size

        // Mouse move and up events
        document.addEventListener('mousemove', (e) => {
            if (this.isAlprDragging) {
                this.handleALPRDrag(e);
            }
        });

        document.addEventListener('mouseup', () => {
            if (this.isAlprDragging) {
                this.stopALPRDragResize();
            }
        });
    }

    toggleALPRWindow() {
        // Open the dedicated ALPR interface instead of the embedded one
        this.openDedicatedALPR();
    }

    openDedicatedALPR() {
        console.log('[MDTInterface] Opening dedicated ALPR interface');
        
        // Get player data for unit name
        const unitName = '1-LINCOLN-18'; // Default unit name
        
        // Send NUI message to open ALPR with proper data (keep main UI visible).
        // IMPORTANT: Do NOT call closeMainUI or close here.
        window.postMessage({
            action: 'ALPR_OPEN',
            unit: unitName
        }, '*');
        // Also show the dedicated overlay container directly
        const overlay = document.getElementById('alpr-container');
        if (overlay) {
            overlay.classList.add('fullscreen-overlay');
            overlay.style.display = 'flex';
        }
        // Hide vehicle info modal if it somehow remained
        const vim = document.getElementById('vehicle-info-modal');
        if (vim) vim.style.display = 'none';
        
        console.log('[MDTInterface] ALPR interface opened');
    }

    openDedicatedASE() {
        console.log('[MDTInterface] Toggling compact ASE window');
        
        const aseWindow = document.getElementById('ase-window');
        if (!aseWindow) {
            console.error('[MDTInterface] ASE window not found!');
            return;
        }
        
        // Toggle window visibility
        if (aseWindow.style.display === 'none' || aseWindow.style.display === '') {
            // Open the window
            aseWindow.style.display = 'block';
            
            // Position window in center if not positioned
            if (!aseWindow.style.left && !aseWindow.style.top) {
                aseWindow.style.left = '50%';
                aseWindow.style.top = '50%';
                aseWindow.style.transform = 'translate(-50%, -50%)';
            }
            
            console.log('[MDTInterface] Compact ASE window opened');
            this.sendNui('aseOpened', {});
        } else {
            // Close the window
            aseWindow.style.display = 'none';
            console.log('[MDTInterface] Compact ASE window closed');
            this.sendNui('aseClosed', {});
        }
    }

    async loadALPRInterface() {
        try {
            const response = await fetch('alpr.html');
            const html = await response.text();
            
            const alprContainer = document.getElementById('alpr-container');
            alprContainer.innerHTML = html;
            alprContainer.style.display = 'none'; // Keep hidden until user clicks ALPR tab
            
            // Load ALPR styles
            const link = document.createElement('link');
            link.rel = 'stylesheet';
            link.href = 'alpr-styles.css';
            document.head.appendChild(link);
            
            console.log('[MDTInterface] ALPR interface loaded');
        } catch (error) {
            console.error('[MDTInterface] Error loading ALPR interface:', error);
        }
    }

    openALPRWindow() {
        this.alprWindow.style.display = 'block';
        this.updateALPRPosition();
        this.updateALPRContent();
        console.log('[MDTInterface] ALPR window opened');
        
        // Debug image loading
        const vehicleImage = this.alprWindow.querySelector('.vehicle-image');
        if (vehicleImage) {
            console.log('[MDTInterface] Vehicle image src:', vehicleImage.src);
            console.log('[MDTInterface] Vehicle image complete:', vehicleImage.complete);
        }
        
        // Test plate image loading
        this.testPlateImageLoading();
    }

    testPlateImageLoading() {
        // Create a test plate to see if images load
        const testPlate = {
            plate: 'TEST123',
            plateType: 'blue',
            source: 'Front',
            timestamp: Date.now(),
            flags: []
        };
        
        console.log('[MDTInterface] Testing plate image loading...');
        this.updateSelectedPlateDisplay(testPlate);
    }

    async verifyImagePath(url) {
        try {
            const response = await fetch(url, { method: 'HEAD' });
            console.log('[MDTInterface] Image HEAD status:', response.status, url);
            return response.status === 200;
        } catch (e) {
            console.error('[MDTInterface] Image fetch failed:', url, e);
            return false;
        }
    }

    closeALPRWindow() {
        this.alprWindow.style.display = 'none';
        this.alprActive = false;
        this.updateALPRStatus();
        console.log('[MDTInterface] ALPR window closed');
    }

    minimizeALPRWindow() {
        this.alprWindow.classList.toggle('minimized');
    }

    toggleALPRSystem() {
        console.log('[MDTInterface] toggleALPRSystem called, current state:', this.alprActive);
        this.alprActive = !this.alprActive;
        this.updateALPRStatus();
        
        if (this.alprActive) {
            console.log('[MDTInterface] Starting ALPR system...');
            this.postToLua('startALPR', {});
        } else {
            console.log('[MDTInterface] Stopping ALPR system...');
            this.postToLua('stopALPR', {});
        }
    }

    updateALPRStatus() {
        const statusElement = document.getElementById('alpr-status');
        const toggleButton = document.getElementById('alpr-toggle');
        
        if (this.alprActive) {
            statusElement.textContent = 'SCANNING';
            statusElement.className = 'alpr-status-indicator scanning';
            toggleButton.textContent = 'STOP';
            toggleButton.classList.add('active');
        } else {
            statusElement.textContent = 'OFFLINE';
            statusElement.className = 'alpr-status-indicator offline';
            toggleButton.textContent = '🔍';
            toggleButton.classList.remove('active');
        }
    }

    addDetectedPlate(plateData) {
        console.log('[MDTInterface] addDetectedPlate called with:', plateData);
        
        // Check if plate already exists
        const existingPlate = this.detectedPlates.find(p => p.plate === plateData.plate);
        if (existingPlate) {
            console.log('[MDTInterface] Updating existing plate:', plateData.plate);
            // Update existing plate data
            existingPlate.timestamp = plateData.timestamp;
            existingPlate.source = plateData.source;
            existingPlate.flags = plateData.flags;
            existingPlate.model = plateData.model;
            existingPlate.coords = plateData.coords;
            
            // Don't auto-select if it's just an update
            // Only update the list display
            this.updateALPRPlatesList();
        } else {
            console.log('[MDTInterface] Adding new plate:', plateData.plate);
            // Add new plate
            this.detectedPlates.unshift(plateData);
            
            // Auto-select the newest plate
            this.selectPlate(plateData.plate);
            
            // Update the list display
            this.updateALPRPlatesList();
        }

        // Limit to 50 plates
        if (this.detectedPlates.length > 50) {
            this.detectedPlates = this.detectedPlates.slice(0, 50);
        }

        console.log('[MDTInterface] Total detected plates:', this.detectedPlates.length);
        
        // Check for BOLO alerts
        if (plateData.flags && plateData.flags.includes('bolo')) {
            this.showBOLOAlert(plateData);
        }
    }

    updateALPRPlatesList() {
        console.log('[MDTInterface] updateALPRPlatesList called, plates count:', this.detectedPlates.length);
        const platesList = document.getElementById('alpr-plates-list') || document.getElementById('plates-list');
        const countEl = document.getElementById('plates-count');
        if (countEl) {
            countEl.textContent = `${this.detectedPlates.length} plates scanned`;
        }
        
        if (this.detectedPlates.length === 0) {
            platesList.innerHTML = `
                <div class="no-plates-message">
                    <div class="no-plates-icon">🚗</div>
                    <div class="no-plates-text">No Plates Detected</div>
                    <div class="no-plates-subtext">Drive near vehicles to scan plates</div>
                </div>
            `;
            return;
        }

        platesList.innerHTML = this.detectedPlates.map(plate => {
            const flags = plate.flags ? plate.flags.map(flag => 
                `<span class="plate-flag ${flag}">${flag.toUpperCase()}</span>`
            ).join('') : '';
            
            return `
                <div class="plate-entry" data-plate="${plate.plate}">
                    <div class="plate-info">
                        <div class="plate-number">${plate.plate}</div>
                        <div class="plate-source">${plate.source}</div>
                    </div>
                    <div class="plate-flags">${flags}</div>
                </div>
            `;
        }).join('');

        // Add click handlers for plate selection
        platesList.querySelectorAll('.plate-entry').forEach(entry => {
            entry.addEventListener('click', (e) => {
                console.log('[MDTInterface] Plate entry clicked:', entry.dataset.plate);
                e.preventDefault();
                e.stopPropagation();
                this.selectPlate(entry.dataset.plate);
            });
        });
    }

    selectPlate(plateNumber) {
        console.log('[MDTInterface] selectPlate called with:', plateNumber);
        const plate = this.detectedPlates.find(p => p.plate === plateNumber);
        if (!plate) {
            console.log('[MDTInterface] Plate not found in detectedPlates:', plateNumber);
            return;
        }

        console.log('[MDTInterface] Found plate data:', plate);
        this.selectedPlate = plate;
        
        // Update selection in list
        document.querySelectorAll('.plate-entry').forEach(entry => {
            entry.classList.remove('selected');
        });
        
        const plateEntry = document.querySelector(`[data-plate="${plateNumber}"]`);
        if (plateEntry) {
            plateEntry.classList.add('selected');
            console.log('[MDTInterface] Added selected class to plate entry');
        } else {
            console.log('[MDTInterface] Could not find plate entry element for:', plateNumber);
        }

        // Update selected plate display
        this.updateSelectedPlateDisplay(plate);
        console.log('[MDTInterface] Updated selected plate display');
    }

    updateSelectedPlateDisplay(plate) {
        console.log('[MDTInterface] updateSelectedPlateDisplay called with:', plate);
        const plateNumberElement = document.getElementById('selected-plate-number');
        if (plateNumberElement) {
            plateNumberElement.textContent = plate.plate;
            console.log('[MDTInterface] Updated plate number element to:', plate.plate);
        } else {
            console.log('[MDTInterface] Could not find selected-plate-number element');
        }
        
        // Update the plate image/display
        const imgElement = document.getElementById('selected-plate-image');
        if (imgElement) {
            console.log('[MDTInterface] Found selected-plate-image element, updating...');
            this.setPlateImageSource(imgElement, 'blue', plate.plate);
        } else {
            console.log('[MDTInterface] Could not find selected-plate-image element');
        }

        // Render glyph preview on right panel if present
        this.renderSelectedPlateGlyphs(plate.plate);
    }

    renderSelectedPlateGlyphs(plateNumber) {
        const glyphsContainer = document.getElementById('plate-glyphs');
        if (!glyphsContainer) return;
        const safe = (plateNumber || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
        const basePath = 'plates/yellow_27x55';
        glyphsContainer.innerHTML = Array.from(safe).map(ch => {
            const filename = /[0-9]/.test(ch) ? ch : ch;
            return `<img class="glyph" alt="${ch}" src="${basePath}/${filename}.png">`;
        }).join('');
    }

    setPlateImageSource(imgElement, plateType = 'blue', plateNumber = null) {
        // Use the plate background image (BlueOnWhite1)
        const path = this.generatePlateImage(plateNumber || '');
        imgElement.src = path;
        imgElement.style.display = 'block';
    }

    setVehicleImageSource(imgElement) {
        const candidates = [
            'INTERFACE/vehiclealprinterface.png',
            './INTERFACE/vehiclealprinterface.png',
            '/INTERFACE/vehiclealprinterface.png'
        ];
        const tryNext = (idx) => {
            if (idx >= candidates.length) {
                console.warn('[MDTInterface] Could not load vehicle interface image, leaving empty');
                return;
            }
            const url = candidates[idx];
            const testImg = new Image();
            testImg.onload = () => { imgElement.src = url; };
            testImg.onerror = () => tryNext(idx + 1);
            testImg.src = url;
        };
        tryNext(0);
    }

    generatePlateImage(plateNumber, plateType = 'blue') {
        // For now, return a placeholder. In a real implementation, you'd combine the individual character images
        // Try different path formats for FiveM compatibility
        const possiblePaths = [
            'plates/BlueOnWhite1.png',
            './plates/BlueOnWhite1.png',
            '/plates/BlueOnWhite1.png',
            window.location.origin + '/nui/plates/BlueOnWhite1.png',
            window.location.origin + '/plates/BlueOnWhite1.png'
        ];
        
        // Return the first path for now, the error handling will try others
        return possiblePaths[0];
    }

    showPlateInfo() {
        if (!this.selectedPlate) return;

        const modal = document.getElementById('plate-info-modal');
        const modalBody = document.getElementById('modal-body');
        
        modal.style.display = 'flex';
        modalBody.innerHTML = `
            <div class="vehicle-info-loading">
                <div class="loading-spinner"></div>
                <div class="loading-text">Loading vehicle information...</div>
            </div>
        `;

        // Set a timeout to prevent infinite loading
        this.vehicleInfoTimeout = setTimeout(() => {
            console.log('[MDTInterface] Vehicle info request timed out');
            modalBody.innerHTML = `
                <div class="vehicle-info">
                    <div class="vehicle-info-item">
                        <span class="vehicle-info-label">Plate:</span>
                        <span class="vehicle-info-value">${this.selectedPlate.plate}</span>
                    </div>
                    <div class="vehicle-info-item">
                        <span class="vehicle-info-label">Status:</span>
                        <span class="vehicle-info-value error">Request Timeout</span>
                    </div>
                    <div class="vehicle-info-warning">
                        <div class="warning-icon">⚠️</div>
                        <div class="warning-text">
                            <strong>REQUEST TIMEOUT</strong><br>
                            Unable to retrieve vehicle information. Please try again.
                        </div>
                    </div>
                </div>
            `;
        }, 10000); // 10 second timeout

        // Request vehicle info from server
        this.postToLua('getVehicleInfo', { plate: this.selectedPlate.plate });
    }

    closePlateInfoModal() {
        // Clear any pending timeout
        if (this.vehicleInfoTimeout) {
            clearTimeout(this.vehicleInfoTimeout);
            this.vehicleInfoTimeout = null;
        }
        
        document.getElementById('plate-info-modal').style.display = 'none';
    }

    updateVehicleInfo(vehicleData) {
        // Clear the timeout since we received a response
        if (this.vehicleInfoTimeout) {
            clearTimeout(this.vehicleInfoTimeout);
            this.vehicleInfoTimeout = null;
        }

        const modalBody = document.getElementById('modal-body');
        
        if (!vehicleData) {
            modalBody.innerHTML = `
                <div class="vehicle-info">
                    <div class="vehicle-info-item">
                        <span class="vehicle-info-label">Plate:</span>
                        <span class="vehicle-info-value">${this.selectedPlate.plate}</span>
                    </div>
                    <div class="vehicle-info-item">
                        <span class="vehicle-info-label">Status:</span>
                        <span class="vehicle-info-value error">No Data Found</span>
                    </div>
                </div>
            `;
            return;
        }

        // Check if vehicle is stolen/unregistered
        const isStolen = vehicleData.isStolen || vehicleData.status === 'STOLEN/UNREGISTERED';
        const statusClass = isStolen ? 'error' : 'success';
        const statusIcon = isStolen ? '🚨' : '✅';

        modalBody.innerHTML = `
            <div class="vehicle-info">
                <div class="vehicle-info-header ${isStolen ? 'stolen' : 'registered'}">
                    <div class="vehicle-status">
                        <span class="status-icon">${statusIcon}</span>
                        <span class="status-text ${statusClass}">${vehicleData.status || 'Unknown'}</span>
                    </div>
                </div>
                <div class="vehicle-info-item">
                    <span class="vehicle-info-label">Plate:</span>
                    <span class="vehicle-info-value">${vehicleData.plate}</span>
                </div>
                <div class="vehicle-info-item">
                    <span class="vehicle-info-label">Model:</span>
                    <span class="vehicle-info-value">${vehicleData.model || 'Unknown Model'}</span>
                </div>
                <div class="vehicle-info-item">
                    <span class="vehicle-info-label">Owner:</span>
                    <span class="vehicle-info-value ${isStolen ? 'error' : ''}">${vehicleData.owner || 'Unknown'}</span>
                </div>
                <div class="vehicle-info-item">
                    <span class="vehicle-info-label">Registration:</span>
                    <span class="vehicle-info-value ${isStolen ? 'error' : 'success'}">${vehicleData.registration || 'Unknown'}</span>
                </div>
                <div class="vehicle-info-item">
                    <span class="vehicle-info-label">Insurance:</span>
                    <span class="vehicle-info-value ${isStolen ? 'error' : 'success'}">${vehicleData.insurance || 'Unknown'}</span>
                </div>
                ${vehicleData.searchedBy ? `
                <div class="vehicle-info-item">
                    <span class="vehicle-info-label">Searched By:</span>
                    <span class="vehicle-info-value">${vehicleData.searchedBy}</span>
                </div>
                ` : ''}
                ${vehicleData.timestamp ? `
                <div class="vehicle-info-item">
                    <span class="vehicle-info-label">Search Time:</span>
                    <span class="vehicle-info-value">${new Date(vehicleData.timestamp * 1000).toLocaleString()}</span>
                </div>
                ` : ''}
                ${isStolen ? `
                <div class="vehicle-info-warning">
                    <div class="warning-icon">⚠️</div>
                    <div class="warning-text">
                        <strong>STOLEN/UNREGISTERED VEHICLE</strong><br>
                        This vehicle is not registered in the database. Proceed with caution.
                    </div>
                </div>
                ` : ''}
            </div>
        `;
    }

    displayVehicleInfoInDispatch(vehicleData) {
        console.log('[MDTInterface] Displaying vehicle info in dispatch screen:', vehicleData);
        
        // Determine if vehicle is stolen
        const isStolen = vehicleData.isStolen || vehicleData.status === 'STOLEN/UNREGISTERED' || 
                        (vehicleData.flags && vehicleData.flags.includes('stolen'));
        
        const statusIcon = isStolen ? '🚨' : '✅';
        const statusClass = isStolen ? 'error' : 'success';
        
        // Update the popout window content
        const popoutDetails = document.getElementById('popout-details');
        if (popoutDetails) {
            popoutDetails.innerHTML = `
                <div class="vehicle-dispatch-info">
                    <div class="vehicle-dispatch-header">
                        <div class="vehicle-dispatch-title">
                            <span class="vehicle-icon">🚗</span>
                            <span>ALPR Vehicle Check</span>
                        </div>
                        <div class="vehicle-status-badge ${statusClass}">
                            <span class="status-icon">${statusIcon}</span>
                            <span class="status-text">${vehicleData.status || 'Unknown'}</span>
                        </div>
                    </div>
                    <div class="vehicle-dispatch-details">
                        <div class="vehicle-detail-row">
                            <span class="detail-label">Plate:</span>
                            <span class="detail-value">${vehicleData.plate}</span>
                        </div>
                        <div class="vehicle-detail-row">
                            <span class="detail-label">Model:</span>
                            <span class="detail-value">${vehicleData.model || 'Unknown Model'}</span>
                        </div>
                        <div class="vehicle-detail-row">
                            <span class="detail-label">Owner:</span>
                            <span class="detail-value ${isStolen ? 'error' : ''}">${vehicleData.owner || 'Unknown'}</span>
                        </div>
                        <div class="vehicle-detail-row">
                            <span class="detail-label">Registration:</span>
                            <span class="detail-value ${isStolen ? 'error' : 'success'}">${vehicleData.registration || 'Unknown'}</span>
                        </div>
                        <div class="vehicle-detail-row">
                            <span class="detail-label">Insurance:</span>
                            <span class="detail-value ${isStolen ? 'error' : 'success'}">${vehicleData.insurance || 'Unknown'}</span>
                        </div>
                        ${vehicleData.searchedBy ? `
                        <div class="vehicle-detail-row">
                            <span class="detail-label">Searched By:</span>
                            <span class="detail-value">${vehicleData.searchedBy}</span>
                        </div>
                        ` : ''}
                        <div class="vehicle-detail-row">
                            <span class="detail-label">Time:</span>
                            <span class="detail-value">${new Date().toLocaleTimeString()}</span>
                        </div>
                    </div>
                </div>
            `;
        }
        
        // Update the popout window title to indicate ALPR activity
        const popoutTitle = document.querySelector('.popout-title');
        if (popoutTitle) {
            popoutTitle.textContent = `Dispatch Info - ALPR Alert`;
        }
        
        // Show the popout window if it's not already visible
        const popoutWindow = document.getElementById('popout-window');
        if (popoutWindow && popoutWindow.style.display === 'none') {
            popoutWindow.style.display = 'block';
        }
    }

    showBOLOAlert(plateData) {
        const alert = document.getElementById('bolo-alert');
        const plateElement = document.getElementById('bolo-plate');
        const descriptionElement = document.getElementById('bolo-description');
        
        plateElement.textContent = plateData.plate;
        descriptionElement.textContent = 'Vehicle flagged in BOLO database';
        
        alert.style.display = 'block';
        
        // Auto-hide after 5 seconds
        setTimeout(() => {
            alert.style.display = 'none';
        }, 5000);
    }

    startALPRDrag(e) {
        this.isAlprDragging = true;
        this.alprDragStart = {
            x: e.clientX - this.alprRect.x,
            y: e.clientY - this.alprRect.y
        };
        e.preventDefault();
    }

    // Resize function removed - window is now fixed size

    handleALPRDrag(e) {
        this.alprRect.x = e.clientX - this.alprDragStart.x;
        this.alprRect.y = e.clientY - this.alprDragStart.y;
        this.updateALPRPosition();
    }

    // Resize function removed - window is now fixed size

    stopALPRDragResize() {
        this.isAlprDragging = false;
    }

    updateALPRPosition() {
        this.alprWindow.style.left = this.alprRect.x + 'px';
        this.alprWindow.style.top = this.alprRect.y + 'px';
    }

    // Size update function removed - window is now fixed size

    updateALPRContent() {
        this.updateALPRStatus();
        this.updateALPRPlatesList();
    }

    // Play audio file using the bullet-proof audio player
    playAudio(audioFile, volume = 1.0, delay = 0) {
        console.log('Playing audio:', audioFile, 'Volume:', volume, 'Delay:', delay);
        
        // Use the dedicated audio player for bullet-proof playback
        if (window.audioPlayer) {
            window.audioPlayer.playAudio(audioFile, volume, delay);
        } else {
            console.error('Audio player not available');
        }
    }

    // Audio queue is now handled by the dedicated audio player
    // This method is kept for compatibility but no longer needed
    processAudioQueue() {
        console.log('Audio queue processing moved to dedicated audio player');
    }

    // Test audio system
    testAudio(message) {
        console.log('Testing audio system:', message);
        
        // Use the dedicated audio player for testing
        if (window.audioPlayer) {
            window.audioPlayer.testAudio();
        } else {
            console.error('Audio player not available for testing');
        }
    }
}

// Initialize the interface
const mdtInterface = new MDTInterface();

// Listen for messages from Lua
window.addEventListener('message', (event) => {
    mdtInterface.handleMessage(event.data);
});

// Helper function to get resource name
function GetParentResourceName() {
    return window.location.hostname;
}
