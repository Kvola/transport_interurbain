/** @odoo-module **/

import { registry } from "@web/core/registry";
import { Component, useState, onWillStart, onMounted } from "@odoo/owl";
import { useService } from "@web/core/utils/hooks";
import { _t } from "@web/core/l10n/translation";

/**
 * Dashboard Administrateur Intelligent
 * Affiche les KPIs, tendances, alertes et prédictions
 */
class TransportAdminDashboard extends Component {
    static template = "transport_interurbain.AdminDashboard";
    static props = ["*"];

    setup() {
        this.orm = useService("orm");
        this.action = useService("action");
        this.rpc = useService("rpc");
        this.notification = useService("notification");
        
        this.state = useState({
            loading: true,
            lastUpdate: null,
            // Statistiques globales
            totalTrips: 0,
            scheduledTrips: 0,
            completedTrips: 0,
            cancelledTrips: 0,
            boardingTrips: 0,
            // Réservations
            totalBookings: 0,
            confirmedBookings: 0,
            reservedBookings: 0,
            todayBookings: 0,
            unpaidBookings: 0,
            expiringReservations: 0,
            // Revenus
            totalRevenue: 0,
            todayRevenue: 0,
            weekRevenue: 0,
            monthRevenue: 0,
            lastMonthRevenue: 0,
            revenueGrowth: 0,
            // Compagnies
            totalCompanies: 0,
            activeCompanies: 0,
            // Clients
            totalPassengers: 0,
            newPassengersThisMonth: 0,
            // Performance
            avgOccupancyRate: 0,
            avgRating: 0,
            cancellationRate: 0,
            // Alertes intelligentes
            alerts: [],
            // Tendances (derniers 7 jours)
            weeklyTrips: [],
            weeklyRevenue: [],
            weeklyBookings: [],
            // Top données
            topRoutes: [],
            topCompanies: [],
            recentBookings: [],
            // Prédictions
            predictedRevenue: 0,
            predictedBookings: 0,
            // Comparaisons
            tripsTrend: 0, // % vs semaine précédente
            bookingsTrend: 0,
            revenueTrend: 0,
        });

        onWillStart(async () => {
            await this.loadDashboardData();
        });
        
        onMounted(() => {
            // Auto-refresh toutes les 5 minutes
            this.refreshInterval = setInterval(() => this.loadDashboardData(), 300000);
        });
    }
    
    willUnmount() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
        }
    }

    async loadDashboardData() {
        this.state.loading = true;
        try {
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
            const [totalTrips, scheduledTrips, completedTrips, cancelledTrips, boardingTrips] = await Promise.all([
                this.orm.searchCount("transport.trip", []),
                this.orm.searchCount("transport.trip", [["state", "=", "scheduled"]]),
                this.orm.searchCount("transport.trip", [["state", "=", "completed"]]),
                this.orm.searchCount("transport.trip", [["state", "=", "cancelled"]]),
                this.orm.searchCount("transport.trip", [["state", "=", "boarding"]]),
            ]);
            
            Object.assign(this.state, { totalTrips, scheduledTrips, completedTrips, cancelledTrips, boardingTrips });
            
            // Taux d'annulation
            this.state.cancellationRate = totalTrips > 0 ? Math.round((cancelledTrips / totalTrips) * 100) : 0;
            
            // ============ STATISTIQUES RÉSERVATIONS ============
            const [totalBookings, confirmedBookings, reservedBookings, unpaidBookings] = await Promise.all([
                this.orm.searchCount("transport.booking", []),
                this.orm.searchCount("transport.booking", [["state", "=", "confirmed"]]),
                this.orm.searchCount("transport.booking", [["state", "=", "reserved"]]),
                this.orm.searchCount("transport.booking", [["amount_due", ">", 0], ["state", "not in", ["cancelled", "expired", "refunded"]]]),
            ]);
            
            const todayBookings = await this.orm.searchCount("transport.booking", [["booking_date", ">=", today]]);
            
            // Réservations expirant bientôt (dans les 2 prochaines heures)
            const twoHoursLater = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();
            const expiringReservations = await this.orm.searchCount("transport.booking", [
                ["state", "=", "reserved"],
                ["reservation_deadline", "<=", twoHoursLater],
                ["reservation_deadline", ">", new Date().toISOString()],
            ]);
            
            Object.assign(this.state, { 
                totalBookings, confirmedBookings, reservedBookings, 
                todayBookings, unpaidBookings, expiringReservations 
            });
            
            // ============ REVENUS ============
            const confirmedBookingsData = await this.orm.searchRead(
                "transport.booking",
                [["state", "in", ["confirmed", "completed", "checked_in"]]],
                ["total_amount", "booking_date", "create_date"]
            );
            
            this.state.totalRevenue = confirmedBookingsData.reduce((sum, b) => sum + (b.total_amount || 0), 0);
            
            // Revenus d'aujourd'hui
            const todayBookingsRevenue = confirmedBookingsData.filter(b => b.booking_date >= today);
            this.state.todayRevenue = todayBookingsRevenue.reduce((sum, b) => sum + (b.total_amount || 0), 0);
            
            // Revenus de la semaine
            const weekBookingsRevenue = confirmedBookingsData.filter(b => b.booking_date >= weekAgo);
            this.state.weekRevenue = weekBookingsRevenue.reduce((sum, b) => sum + (b.total_amount || 0), 0);
            
            // Revenus du mois
            const monthBookingsRevenue = confirmedBookingsData.filter(b => b.booking_date >= monthStart.toISOString().split('T')[0]);
            this.state.monthRevenue = monthBookingsRevenue.reduce((sum, b) => sum + (b.total_amount || 0), 0);
            
            // Revenus du mois précédent (pour comparaison)
            const lastMonthBookingsRevenue = confirmedBookingsData.filter(b => 
                b.booking_date >= lastMonthStart.toISOString().split('T')[0] &&
                b.booking_date <= lastMonthEnd.toISOString().split('T')[0]
            );
            this.state.lastMonthRevenue = lastMonthBookingsRevenue.reduce((sum, b) => sum + (b.total_amount || 0), 0);
            
            // Croissance des revenus
            if (this.state.lastMonthRevenue > 0) {
                this.state.revenueGrowth = Math.round(
                    ((this.state.monthRevenue - this.state.lastMonthRevenue) / this.state.lastMonthRevenue) * 100
                );
            }
            
            // ============ TENDANCES SEMAINE ============
            // Calculer les tendances sur les 7 derniers jours
            const weeklyData = this._calculateWeeklyData(confirmedBookingsData);
            this.state.weeklyRevenue = weeklyData.revenues;
            this.state.weeklyBookings = weeklyData.counts;
            
            // Comparer cette semaine vs semaine précédente
            const thisWeekBookings = confirmedBookingsData.filter(b => b.booking_date >= weekAgo).length;
            const lastWeekBookings = confirmedBookingsData.filter(b => 
                b.booking_date >= twoWeeksAgo && b.booking_date < weekAgo
            ).length;
            
            if (lastWeekBookings > 0) {
                this.state.bookingsTrend = Math.round(((thisWeekBookings - lastWeekBookings) / lastWeekBookings) * 100);
            }
            
            const thisWeekRevenue = weekBookingsRevenue.reduce((sum, b) => sum + (b.total_amount || 0), 0);
            const lastWeekRevenueData = confirmedBookingsData.filter(b => 
                b.booking_date >= twoWeeksAgo && b.booking_date < weekAgo
            );
            const lastWeekRevenue = lastWeekRevenueData.reduce((sum, b) => sum + (b.total_amount || 0), 0);
            
            if (lastWeekRevenue > 0) {
                this.state.revenueTrend = Math.round(((thisWeekRevenue - lastWeekRevenue) / lastWeekRevenue) * 100);
            }
            
            // ============ COMPAGNIES ET CLIENTS ============
            const [totalCompanies, activeCompanies, totalPassengers] = await Promise.all([
                this.orm.searchCount("transport.company", []),
                this.orm.searchCount("transport.company", [["state", "=", "active"]]),
                this.orm.searchCount("transport.passenger", []),
            ]);
            
            // Nouveaux passagers ce mois
            const newPassengersThisMonth = await this.orm.searchCount("transport.passenger", [
                ["create_date", ">=", monthStart.toISOString()]
            ]);
            
            Object.assign(this.state, { totalCompanies, activeCompanies, totalPassengers, newPassengersThisMonth });
            
            // ============ TAUX D'OCCUPATION ============
            const tripsWithBookings = await this.orm.searchRead(
                "transport.trip",
                [["state", "in", ["scheduled", "boarding", "departed"]]],
                ["total_seats", "available_seats"]
            );
            
            if (tripsWithBookings.length > 0) {
                const totalSeats = tripsWithBookings.reduce((sum, t) => sum + (t.total_seats || 0), 0);
                const bookedSeats = tripsWithBookings.reduce((sum, t) => sum + ((t.total_seats || 0) - (t.available_seats || 0)), 0);
                this.state.avgOccupancyRate = totalSeats > 0 ? Math.round((bookedSeats / totalSeats) * 100) : 0;
            }
            
            // ============ NOTE MOYENNE ============
            const companiesWithRating = await this.orm.searchRead(
                "transport.company",
                [["rating", ">", 0]],
                ["rating", "rating_count"]
            );
            
            if (companiesWithRating.length > 0) {
                const totalRatingWeight = companiesWithRating.reduce((sum, c) => sum + (c.rating * c.rating_count), 0);
                const totalRatingCount = companiesWithRating.reduce((sum, c) => sum + c.rating_count, 0);
                this.state.avgRating = totalRatingCount > 0 ? (totalRatingWeight / totalRatingCount).toFixed(1) : 0;
            }
            
            // ============ TOP ITINÉRAIRES ============
            const routes = await this.orm.searchRead(
                "transport.route",
                [["state", "=", "active"]],
                ["name", "departure_city_id", "arrival_city_id", "base_price"],
                { limit: 5, order: "id desc" }
            );
            this.state.topRoutes = routes;
            
            // ============ TOP COMPAGNIES ============
            const companies = await this.orm.searchRead(
                "transport.company",
                [["state", "=", "active"]],
                ["name", "rating", "rating_count"],
                { order: "rating desc, rating_count desc", limit: 5 }
            );
            this.state.topCompanies = companies;
            
            // ============ RÉSERVATIONS RÉCENTES ============
            const recentBookings = await this.orm.searchRead(
                "transport.booking",
                [],
                ["name", "passenger_name", "total_amount", "amount_due", "state", "booking_date", "trip_id"],
                { order: "create_date desc", limit: 10 }
            );
            this.state.recentBookings = recentBookings;
            
            // ============ ALERTES INTELLIGENTES ============
            this._generateAlerts();
            
            // ============ PRÉDICTIONS ============
            this._generatePredictions(confirmedBookingsData);
            
            this.state.lastUpdate = new Date().toLocaleTimeString('fr-FR');
            
        } catch (error) {
            console.error("Erreur chargement dashboard:", error);
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
        
        return { revenues, counts };
    }
    
    _generateAlerts() {
        const alerts = [];
        
        // Alerte: Réservations expirant bientôt
        if (this.state.expiringReservations > 0) {
            alerts.push({
                type: 'warning',
                icon: 'fa-clock-o',
                title: 'Réservations à expirer',
                message: `${this.state.expiringReservations} réservation(s) expirent dans les 2 prochaines heures`,
                action: 'openExpiringReservations'
            });
        }
        
        // Alerte: Voyages en cours d'embarquement
        if (this.state.boardingTrips > 0) {
            alerts.push({
                type: 'info',
                icon: 'fa-bus',
                title: 'Embarquement en cours',
                message: `${this.state.boardingTrips} voyage(s) en cours d'embarquement`,
                action: 'openBoardingTrips'
            });
        }
        
        // Alerte: Réservations impayées importantes
        if (this.state.unpaidBookings > 10) {
            alerts.push({
                type: 'danger',
                icon: 'fa-exclamation-triangle',
                title: 'Paiements en attente',
                message: `${this.state.unpaidBookings} réservations non payées`,
                action: 'openUnpaidBookings'
            });
        }
        
        // Alerte: Taux d'occupation faible
        if (this.state.avgOccupancyRate < 30 && this.state.scheduledTrips > 0) {
            alerts.push({
                type: 'warning',
                icon: 'fa-line-chart',
                title: 'Occupation faible',
                message: `Taux d'occupation moyen de ${this.state.avgOccupancyRate}% seulement`,
                action: null
            });
        }
        
        // Alerte positive: Croissance des revenus
        if (this.state.revenueGrowth > 20) {
            alerts.push({
                type: 'success',
                icon: 'fa-trending-up',
                title: 'Excellente croissance !',
                message: `+${this.state.revenueGrowth}% de revenus par rapport au mois dernier`,
                action: null
            });
        }
        
        // Alerte: Baisse des réservations
        if (this.state.bookingsTrend < -20) {
            alerts.push({
                type: 'danger',
                icon: 'fa-arrow-down',
                title: 'Baisse des réservations',
                message: `${this.state.bookingsTrend}% par rapport à la semaine dernière`,
                action: null
            });
        }
        
        // Alerte: Taux d'annulation élevé
        if (this.state.cancellationRate > 15) {
            alerts.push({
                type: 'warning',
                icon: 'fa-times-circle',
                title: 'Taux d\'annulation élevé',
                message: `${this.state.cancellationRate}% des voyages sont annulés`,
                action: 'openCancelledTrips'
            });
        }
        
        this.state.alerts = alerts;
    }
    
    _generatePredictions(bookingsData) {
        // Prédiction simple basée sur la moyenne des 7 derniers jours
        const last7Days = bookingsData.filter(b => {
            const bookingDate = new Date(b.booking_date);
            const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
            return bookingDate >= weekAgo;
        });
        
        const avgDailyRevenue = last7Days.reduce((sum, b) => sum + (b.total_amount || 0), 0) / 7;
        const avgDailyBookings = last7Days.length / 7;
        
        // Prédiction pour les 7 prochains jours
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

    async openTrips() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Voyages"),
            res_model: "transport.trip",
            views: [[false, "list"], [false, "form"], [false, "calendar"]],
            target: "current",
        });
    }

    async openBookings() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Réservations"),
            res_model: "transport.booking",
            views: [[false, "list"], [false, "form"]],
            target: "current",
        });
    }

    async openCompanies() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Compagnies"),
            res_model: "transport.company",
            views: [[false, "list"], [false, "form"]],
            target: "current",
        });
    }

    async openRoutes() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Itinéraires"),
            res_model: "transport.route",
            views: [[false, "list"], [false, "form"]],
            target: "current",
        });
    }

    async openScheduledTrips() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Voyages Programmés"),
            res_model: "transport.trip",
            views: [[false, "list"], [false, "form"]],
            domain: [["state", "=", "scheduled"]],
            target: "current",
        });
    }
    
    async openBoardingTrips() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Embarquement en cours"),
            res_model: "transport.trip",
            views: [[false, "list"], [false, "form"]],
            domain: [["state", "=", "boarding"]],
            target: "current",
        });
    }
    
    async openCancelledTrips() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Voyages annulés"),
            res_model: "transport.trip",
            views: [[false, "list"], [false, "form"]],
            domain: [["state", "=", "cancelled"]],
            target: "current",
        });
    }

    async openTodayBookings() {
        const today = new Date().toISOString().split('T')[0];
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Réservations du jour"),
            res_model: "transport.booking",
            views: [[false, "list"], [false, "form"]],
            domain: [["booking_date", ">=", today]],
            target: "current",
        });
    }
    
    async openUnpaidBookings() {
        await this.action.doAction({
            type: "ir.actions.act_window",
            name: _t("Réservations impayées"),
            res_model: "transport.booking",
            views: [[false, "list"], [false, "form"]],
            domain: [["amount_due", ">", 0], ["state", "not in", ["cancelled", "expired", "refunded"]]],
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
                ["state", "=", "reserved"],
                ["reservation_deadline", "<=", twoHoursLater],
            ],
            target: "current",
        });
    }
    
    async executeAlertAction(action) {
        if (action && typeof this[action] === 'function') {
            await this[action]();
        }
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
        };
        return classes[state] || 'bg-secondary';
    }

    async refresh() {
        this.notification.add(_t("Actualisation en cours..."), { type: "info" });
        await this.loadDashboardData();
        this.notification.add(_t("Tableau de bord actualisé"), { type: "success" });
    }
}

TransportAdminDashboard.template = "transport_interurbain.AdminDashboard";

registry.category("actions").add("transport_admin_dashboard", TransportAdminDashboard);

export default TransportAdminDashboard;
