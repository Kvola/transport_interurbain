/** @odoo-module **/

import { registry } from "@web/core/registry";
import { Component, useState, onWillStart, onMounted } from "@odoo/owl";
import { useService } from "@web/core/utils/hooks";
import { _t } from "@web/core/l10n/translation";

/**
 * Dashboard Compagnie Intelligent
 * Affiche les KPIs, tendances, alertes et performances de la compagnie
 */
class TransportCompanyDashboard extends Component {
    static template = "transport_interurbain.CompanyDashboard";
    static props = ["*"];

    setup() {
        this.orm = useService("orm");
        this.action = useService("action");
        this.user = useService("user");
        this.notification = useService("notification");
        
        this.state = useState({
            loading: true,
            lastUpdate: null,
            companyId: null,
            companyName: "",
            companyRating: 0,
            companyRatingCount: 0,
            // Voyages
            totalTrips: 0,
            scheduledTrips: 0,
            todayTrips: 0,
            boardingTrips: 0,
            departedTrips: 0,
            completedTrips: 0,
            cancelledTrips: 0,
            // Réservations
            totalBookings: 0,
            confirmedBookings: 0,
            pendingBookings: 0,
            todayBookings: 0,
            unpaidBookings: 0,
            expiringReservations: 0,
            // Bus
            totalBuses: 0,
            activeBuses: 0,
            inMaintenanceBuses: 0,
            // Revenus
            totalRevenue: 0,
            todayRevenue: 0,
            weekRevenue: 0,
            monthRevenue: 0,
            lastMonthRevenue: 0,
            revenueGrowth: 0,
            // Performance
            avgOccupancyRate: 0,
            cancellationRate: 0,
            onTimeRate: 0,
            // Tendances
            weeklyRevenue: [],
            weeklyBookings: [],
            revenueTrend: 0,
            bookingsTrend: 0,
            // Alertes
            alerts: [],
            // Listes
            upcomingTrips: [],
            recentBookings: [],
            topRoutes: [],
            // Prédictions
            predictedRevenue: 0,
            predictedBookings: 0,
        });

        onWillStart(async () => {
            await this.loadCompanyData();
        });
        
        onMounted(() => {
            // Auto-refresh toutes les 3 minutes
            this.refreshInterval = setInterval(() => this.loadCompanyData(), 180000);
        });
    }
    
    willUnmount() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
        }
    }

    async loadCompanyData() {
        this.state.loading = true;
        
        try {
            // Trouver la compagnie du manager connecté
            const partnerId = this.user.partnerId;
            const companies = await this.orm.searchRead(
                "transport.company",
                [["manager_ids.partner_id", "=", partnerId]],
                ["id", "name", "rating", "rating_count", "state"],
                { limit: 1 }
            );
            
            if (companies.length === 0) {
                this.state.loading = false;
                return;
            }
            
            const company = companies[0];
            this.state.companyId = company.id;
            this.state.companyName = company.name;
            this.state.companyRating = company.rating || 0;
            this.state.companyRatingCount = company.rating_count || 0;
            
            const today = new Date().toISOString().split('T')[0];
            const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
            const twoWeeksAgo = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
            const monthStart = new Date();
            monthStart.setDate(1);
            const lastMonthStart = new Date(monthStart);
            lastMonthStart.setMonth(lastMonthStart.getMonth() - 1);
            const lastMonthEnd = new Date(monthStart);
            lastMonthEnd.setDate(lastMonthEnd.getDate() - 1);
            
            // ============ STATISTIQUES VOYAGES ============
            const [totalTrips, scheduledTrips, boardingTrips, departedTrips, completedTrips, cancelledTrips] = await Promise.all([
                this.orm.searchCount("transport.trip", [["transport_company_id", "=", company.id]]),
                this.orm.searchCount("transport.trip", [["transport_company_id", "=", company.id], ["state", "=", "scheduled"]]),
                this.orm.searchCount("transport.trip", [["transport_company_id", "=", company.id], ["state", "=", "boarding"]]),
                this.orm.searchCount("transport.trip", [["transport_company_id", "=", company.id], ["state", "=", "departed"]]),
                this.orm.searchCount("transport.trip", [["transport_company_id", "=", company.id], ["state", "=", "completed"]]),
                this.orm.searchCount("transport.trip", [["transport_company_id", "=", company.id], ["state", "=", "cancelled"]]),
            ]);
            
            const todayTrips = await this.orm.searchCount("transport.trip", [
                ["transport_company_id", "=", company.id],
                ["departure_date", "=", today]
            ]);
            
            Object.assign(this.state, { 
                totalTrips, scheduledTrips, boardingTrips, departedTrips, 
                completedTrips, cancelledTrips, todayTrips 
            });
            
            // Taux d'annulation
            this.state.cancellationRate = totalTrips > 0 ? Math.round((cancelledTrips / totalTrips) * 100) : 0;
            
            // ============ STATISTIQUES RÉSERVATIONS ============
            const companyBookings = await this.orm.searchRead(
                "transport.booking",
                [["transport_company_id", "=", company.id]],
                ["state", "total_amount", "amount_due", "booking_date", "reservation_deadline"]
            );
            
            this.state.totalBookings = companyBookings.length;
            this.state.confirmedBookings = companyBookings.filter(b => b.state === "confirmed").length;
            this.state.pendingBookings = companyBookings.filter(b => ["draft", "reserved"].includes(b.state)).length;
            this.state.todayBookings = companyBookings.filter(b => b.booking_date >= today).length;
            this.state.unpaidBookings = companyBookings.filter(b => 
                b.amount_due > 0 && !["cancelled", "expired", "refunded"].includes(b.state)
            ).length;
            
            // Réservations expirant bientôt
            const twoHoursLater = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();
            this.state.expiringReservations = companyBookings.filter(b => 
                b.state === "reserved" && 
                b.reservation_deadline && 
                b.reservation_deadline <= twoHoursLater &&
                b.reservation_deadline > new Date().toISOString()
            ).length;
            
            // ============ REVENUS ============
            const confirmedBookings = companyBookings.filter(b => ["confirmed", "completed", "checked_in"].includes(b.state));
            this.state.totalRevenue = confirmedBookings.reduce((sum, b) => sum + (b.total_amount || 0), 0);
            this.state.todayRevenue = confirmedBookings
                .filter(b => b.booking_date >= today)
                .reduce((sum, b) => sum + (b.total_amount || 0), 0);
            
            this.state.weekRevenue = confirmedBookings
                .filter(b => b.booking_date >= weekAgo)
                .reduce((sum, b) => sum + (b.total_amount || 0), 0);
            
            this.state.monthRevenue = confirmedBookings
                .filter(b => b.booking_date >= monthStart.toISOString().split('T')[0])
                .reduce((sum, b) => sum + (b.total_amount || 0), 0);
            
            // Revenus mois précédent
            this.state.lastMonthRevenue = confirmedBookings
                .filter(b => 
                    b.booking_date >= lastMonthStart.toISOString().split('T')[0] &&
                    b.booking_date <= lastMonthEnd.toISOString().split('T')[0]
                )
                .reduce((sum, b) => sum + (b.total_amount || 0), 0);
            
            // Croissance
            if (this.state.lastMonthRevenue > 0) {
                this.state.revenueGrowth = Math.round(
                    ((this.state.monthRevenue - this.state.lastMonthRevenue) / this.state.lastMonthRevenue) * 100
                );
            }
            
            // Tendances semaine
            const thisWeekBookings = confirmedBookings.filter(b => b.booking_date >= weekAgo);
            const lastWeekBookings = confirmedBookings.filter(b => 
                b.booking_date >= twoWeeksAgo && b.booking_date < weekAgo
            );
            
            if (lastWeekBookings.length > 0) {
                this.state.bookingsTrend = Math.round(
                    ((thisWeekBookings.length - lastWeekBookings.length) / lastWeekBookings.length) * 100
                );
            }
            
            const lastWeekRevenue = lastWeekBookings.reduce((sum, b) => sum + (b.total_amount || 0), 0);
            if (lastWeekRevenue > 0) {
                this.state.revenueTrend = Math.round(
                    ((this.state.weekRevenue - lastWeekRevenue) / lastWeekRevenue) * 100
                );
            }
            
            // Données hebdomadaires pour graphique
            this._calculateWeeklyData(confirmedBookings);
            
            // ============ BUS ============
            const [totalBuses, activeBuses, inMaintenanceBuses] = await Promise.all([
                this.orm.searchCount("transport.bus", [["transport_company_id", "=", company.id]]),
                this.orm.searchCount("transport.bus", [["transport_company_id", "=", company.id], ["state", "=", "available"]]),
                this.orm.searchCount("transport.bus", [["transport_company_id", "=", company.id], ["state", "=", "maintenance"]]),
            ]);
            
            Object.assign(this.state, { totalBuses, activeBuses, inMaintenanceBuses });
            
            // ============ TAUX D'OCCUPATION ============
            const upcomingTrips = await this.orm.searchRead(
                "transport.trip",
                [
                    ["transport_company_id", "=", company.id],
                    ["state", "in", ["scheduled", "boarding"]],
                    ["departure_date", ">=", today]
                ],
                ["name", "route_id", "departure_datetime", "available_seats", "total_seats", "state", "bus_id"],
                { order: "departure_datetime asc", limit: 10 }
            );
            this.state.upcomingTrips = upcomingTrips;
            
            if (upcomingTrips.length > 0) {
                const totalSeats = upcomingTrips.reduce((sum, t) => sum + (t.total_seats || 0), 0);
                const bookedSeats = upcomingTrips.reduce((sum, t) => sum + ((t.total_seats || 0) - (t.available_seats || 0)), 0);
                this.state.avgOccupancyRate = totalSeats > 0 ? Math.round((bookedSeats / totalSeats) * 100) : 0;
            }
            
            // ============ RÉSERVATIONS RÉCENTES ============
            const recentBookings = await this.orm.searchRead(
                "transport.booking",
                [["transport_company_id", "=", company.id]],
                ["name", "passenger_name", "passenger_phone", "trip_id", "total_amount", "amount_due", "state", "booking_date", "seat_number"],
                { order: "create_date desc", limit: 10 }
            );
            this.state.recentBookings = recentBookings;
            
            // ============ ALERTES ============
            this._generateAlerts();
            
            // ============ PRÉDICTIONS ============
            this._generatePredictions(confirmedBookings);
            
            this.state.lastUpdate = new Date().toLocaleTimeString('fr-FR');
            
        } catch (error) {
            console.error("Erreur chargement dashboard compagnie:", error);
            this.notification.add(_t("Erreur lors du chargement du tableau de bord"), { type: "danger" });
        }
        
        this.state.loading = false;
    }
    
    _calculateWeeklyData(bookingsData) {
        const revenues = [];
        const counts = [];
        const days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
        
        for (let i = 6; i >= 0; i--) {
            const date = new Date();
            date.setDate(date.getDate() - i);
            const dateStr = date.toISOString().split('T')[0];
            
            const dayBookings = bookingsData.filter(b => b.booking_date === dateStr);
            revenues.push({
                day: days[date.getDay()],
                value: dayBookings.reduce((sum, b) => sum + (b.total_amount || 0), 0)
            });
            counts.push({
                day: days[date.getDay()],
                value: dayBookings.length
            });
        }
        
        this.state.weeklyRevenue = revenues;
        this.state.weeklyBookings = counts;
    }
    
    _generateAlerts() {
        const alerts = [];
        
        // Voyages en cours d'embarquement
        if (this.state.boardingTrips > 0) {
            alerts.push({
                type: 'info',
                icon: 'fa-users',
                title: 'Embarquement en cours',
                message: `${this.state.boardingTrips} voyage(s) en embarquement`,
                action: 'openBoardingTrips',
                priority: 1
            });
        }
        
        // Voyages en route
        if (this.state.departedTrips > 0) {
            alerts.push({
                type: 'primary',
                icon: 'fa-road',
                title: 'Voyages en route',
                message: `${this.state.departedTrips} voyage(s) actuellement en route`,
                action: 'openDepartedTrips',
                priority: 2
            });
        }
        
        // Réservations expirant
        if (this.state.expiringReservations > 0) {
            alerts.push({
                type: 'warning',
                icon: 'fa-clock-o',
                title: 'Réservations à expirer',
                message: `${this.state.expiringReservations} réservation(s) expirent bientôt`,
                action: 'openExpiringReservations',
                priority: 1
            });
        }
        
        // Paiements en attente
        if (this.state.unpaidBookings > 5) {
            alerts.push({
                type: 'danger',
                icon: 'fa-exclamation-triangle',
                title: 'Paiements en attente',
                message: `${this.state.unpaidBookings} réservations non payées`,
                action: 'openUnpaidBookings',
                priority: 1
            });
        }
        
        // Bus en maintenance
        if (this.state.inMaintenanceBuses > 0) {
            alerts.push({
                type: 'secondary',
                icon: 'fa-wrench',
                title: 'Bus en maintenance',
                message: `${this.state.inMaintenanceBuses} bus indisponible(s)`,
                action: 'openMaintenanceBuses',
                priority: 3
            });
        }
        
        // Taux d'occupation faible
        if (this.state.avgOccupancyRate < 30 && this.state.scheduledTrips > 0) {
            alerts.push({
                type: 'warning',
                icon: 'fa-line-chart',
                title: 'Occupation faible',
                message: `Taux d'occupation de ${this.state.avgOccupancyRate}% - pensez à promouvoir vos voyages`,
                action: null,
                priority: 2
            });
        }
        
        // Croissance positive
        if (this.state.revenueGrowth > 10) {
            alerts.push({
                type: 'success',
                icon: 'fa-trending-up',
                title: 'Bonne performance !',
                message: `+${this.state.revenueGrowth}% de revenus ce mois`,
                action: null,
                priority: 4
            });
        }
        
        // Taux d'annulation élevé
        if (this.state.cancellationRate > 10) {
            alerts.push({
                type: 'danger',
                icon: 'fa-times-circle',
                title: 'Taux d\'annulation élevé',
                message: `${this.state.cancellationRate}% de vos voyages sont annulés`,
                action: null,
                priority: 2
            });
        }
        
        // Trier par priorité
        alerts.sort((a, b) => a.priority - b.priority);
        this.state.alerts = alerts;
    }
    
    _generatePredictions(bookingsData) {
        const last7Days = bookingsData.filter(b => {
            const bookingDate = new Date(b.booking_date);
            const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
            return bookingDate >= weekAgo;
        });
        
        const avgDailyRevenue = last7Days.reduce((sum, b) => sum + (b.total_amount || 0), 0) / 7;
        const avgDailyBookings = last7Days.length / 7;
        
        this.state.predictedRevenue = Math.round(avgDailyRevenue * 7);
        this.state.predictedBookings = Math.round(avgDailyBookings * 7);
    }

    formatCurrency(amount) {
        return new Intl.NumberFormat('fr-FR', {
            style: 'currency',
            currency: 'XOF',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0,
        }).format(amount || 0);
    }
    
    formatNumber(num) {
        return new Intl.NumberFormat('fr-FR').format(num || 0);
    }

    formatDateTime(datetime) {
        if (!datetime) return "";
        return new Date(datetime).toLocaleString('fr-FR', {
            day: '2-digit',
            month: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
        });
    }
    
    getTrendClass(trend) {
        if (trend > 0) return 'text-success';
        if (trend < 0) return 'text-danger';
        return 'text-muted';
    }
    
    getTrendIcon(trend) {
        if (trend > 0) return 'fa-arrow-up';
        if (trend < 0) return 'fa-arrow-down';
        return 'fa-minus';
    }
    
    getOccupancyClass(rate) {
        if (rate >= 70) return 'bg-success';
        if (rate >= 40) return 'bg-warning';
        return 'bg-danger';
    }

    getStateLabel(state) {
        const labels = {
            'draft': 'Brouillon',
            'reserved': 'Réservé',
            'confirmed': 'Confirmé',
            'checked_in': 'Embarqué',
            'completed': 'Terminé',
            'cancelled': 'Annulé',
            'expired': 'Expiré',
            'no_show': 'Non présenté',
            'refunded': 'Remboursé',
            'scheduled': 'Programmé',
            'boarding': 'Embarquement',
            'departed': 'En route',
        };
        return labels[state] || state;
    }

    getStateBadgeClass(state) {
        const classes = {
            'draft': 'bg-secondary',
            'reserved': 'bg-warning text-dark',
            'confirmed': 'bg-success',
            'checked_in': 'bg-info',
            'completed': 'bg-primary',
            'cancelled': 'bg-danger',
            'expired': 'bg-dark',
            'no_show': 'bg-danger',
            'refunded': 'bg-secondary',
            'scheduled': 'bg-primary',
            'boarding': 'bg-warning text-dark',
            'departed': 'bg-info',
        };
        return classes[state] || 'bg-secondary';
    }
    
    async executeAlertAction(action) {
        if (action && typeof this[action] === 'function') {
            await this[action]();
        }
    }

    async openMyTrips() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Mes Voyages"),
            res_model: "transport.trip",
            views: [[false, "list"], [false, "form"], [false, "calendar"]],
            domain: [["transport_company_id", "=", this.state.companyId]],
            target: "current",
        });
    }

    async openMyBookings() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Réservations"),
            res_model: "transport.booking",
            views: [[false, "list"], [false, "form"]],
            domain: [["transport_company_id", "=", this.state.companyId]],
            target: "current",
        });
    }

    async openMyBuses() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Mes Bus"),
            res_model: "transport.bus",
            views: [[false, "list"], [false, "form"]],
            domain: [["transport_company_id", "=", this.state.companyId]],
            target: "current",
        });
    }
    
    async openMaintenanceBuses() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Bus en maintenance"),
            res_model: "transport.bus",
            views: [[false, "list"], [false, "form"]],
            domain: [["transport_company_id", "=", this.state.companyId], ["state", "=", "maintenance"]],
            target: "current",
        });
    }

    async openTodayTrips() {
        const today = new Date().toISOString().split('T')[0];
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Voyages du jour"),
            res_model: "transport.trip",
            views: [[false, "list"], [false, "form"]],
            domain: [
                ["transport_company_id", "=", this.state.companyId],
                ["departure_date", "=", today]
            ],
            target: "current",
        });
    }
    
    async openBoardingTrips() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Embarquement en cours"),
            res_model: "transport.trip",
            views: [[false, "list"], [false, "form"]],
            domain: [
                ["transport_company_id", "=", this.state.companyId],
                ["state", "=", "boarding"]
            ],
            target: "current",
        });
    }
    
    async openDepartedTrips() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Voyages en route"),
            res_model: "transport.trip",
            views: [[false, "list"], [false, "form"]],
            domain: [
                ["transport_company_id", "=", this.state.companyId],
                ["state", "=", "departed"]
            ],
            target: "current",
        });
    }
    
    async openUnpaidBookings() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Réservations impayées"),
            res_model: "transport.booking",
            views: [[false, "list"], [false, "form"]],
            domain: [
                ["transport_company_id", "=", this.state.companyId],
                ["amount_due", ">", 0],
                ["state", "not in", ["cancelled", "expired", "refunded"]]
            ],
            target: "current",
        });
    }
    
    async openExpiringReservations() {
        const twoHoursLater = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Réservations expirant bientôt"),
            res_model: "transport.booking",
            views: [[false, "list"], [false, "form"]],
            domain: [
                ["transport_company_id", "=", this.state.companyId],
                ["state", "=", "reserved"],
                ["reservation_deadline", "<=", twoHoursLater],
            ],
            target: "current",
        });
    }

    async createTrip() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Nouveau voyage"),
            res_model: "transport.trip",
            views: [[false, "form"]],
            context: { default_transport_company_id: this.state.companyId },
            target: "current",
        });
    }

    async openTrip(tripId) {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Détail du voyage"),
            res_model: "transport.trip",
            res_id: tripId,
            views: [[false, "form"]],
            target: "current",
        });
    }

    async openBooking(bookingId) {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Détail de la réservation"),
            res_model: "transport.booking",
            res_id: bookingId,
            views: [[false, "form"]],
            target: "current",
        });
    }

    async refresh() {
        this.notification.add(_t("Actualisation en cours..."), { type: "info" });
        await this.loadCompanyData();
        this.notification.add(_t("Tableau de bord actualisé"), { type: "success" });
    }
}

TransportCompanyDashboard.template = "transport_interurbain.CompanyDashboard";

registry.category("actions").add("transport_company_dashboard", TransportCompanyDashboard);

export default TransportCompanyDashboard;
