class Moderation::UserChangesController < ShikimoriController
  include ActionView::Helpers::SanitizeHelper
  before_filter :authenticate_user!, only: [:index, :apply, :deny, :get_anime_lock, :release_anime_lock]
  PENDING_PER_PAGE = 40

  # отображение одной правки
  def show
    set_meta_tags noindex: true, nofollow: true

    @entry = UserChange.includes(:user).find(params[:id])
    @page_title = [
      'Правки пользователей',
      "Правка ##{@entry.id} пользователя #{@entry.user.nickname}"
    ]
  end

  # тултип о правке
  def tooltip
    show
    render 'blocks/tooltip', layout: params.include?('test')
  end

  # отображение списка предложенных пользователями изменений
  def index
    raise Forbidden unless current_user.user_changes_moderator?

    @processed = postload_paginate(params[:page], 25) do
      UserChange
        .includes(:user)
        .includes(:approver)
        .where.not(status: [UserChangeStatus::Pending, UserChangeStatus::Locked])
        .order(updated_at: :desc)
    end

    unless request.xhr?
      @page_title = 'Правки пользователей'
      @pending = UserChange
        .includes(:user)
        .where(status: UserChangeStatus::Pending)
        .order("(case when \"column\"='tags' then 0 when \"column\"='screenshots' then 1 when \"column\"='video' then 2 else 3 end), created_at")
        .limit(PENDING_PER_PAGE)
        .to_a

      @changes_map = {}
      # по конкретному элементу делаем только одно активное изменение
      @pending.each do |change|
        key = "#{change.model} #{change.item_id}"
        if @changes_map[key]
          def change.locked; true; end
        elsif change.screenshots?
          @changes_map[key] = true
        end
      end

      @moderators = User.where(id: User::UserChangesModerators - User::Admins).sort_by { |v| v.nickname.downcase }
    end
  end

  # изменение пользователем чего-либо
  def change
    @resource = UserChange.new user_change_params.merge(user_id: current_user.try(:id) || User::GuestID)

    if @resource.value == @resource.current_value && @resource.source == @resource.item.source
      return redirect_to_back_or_to @resource.item, alert: 'Нет изменений'
    end

    if change.save
      # сразу же применение изменений при apply
      if params[:apply].present?
        params[:id] = change.id
        params[:taken] = true
      else
        redirect_to_back_or_to @resource.item, notice: 'Правка сохранена и будет в ближайшее время рассмотрена модератором. Домо'
      end
    else
      render text: 'Произошла ошибка при создании правки. Пожалуйста, напишите об этом администратору.', status: :unprocessable_entity
    end
  end

  # применение предложенного пользователем изменения
  def apply
    raise Forbidden unless current_user.user_changes_moderator?
    change = UserChange.find(params[:id])

    if change.apply current_user.id, params[:taken]
      Message.create(
        from_id: current_user.id,
        to_id: change.user_id,
        kind: MessageType::Notification,
        body: "Ваша [user_change=#{change.id}]правка[/user_change] для [#{change.item.class.name.downcase}]#{change.item.id}[/#{change.item.class.name.downcase}] принята."
      ) unless change.user_id == current_user.id

      redirect_to_back_or_to moderation_user_changes_url, notice: 'Правка успешно применена'
    else
      render text: "Произошла ошибка при принятии правки. Номер правки ##{change.id}. Пожалуйста, напишите об этом администратору.", status: :unprocessable_entity
    end
  end

  # отказ предложенного пользователем изменения
  def deny
    change = UserChange.find params[:id]
    raise Forbidden unless current_user.user_changes_moderator? || current_user.id == change.user_id

    if change.deny(current_user.id, params[:notify])
      if params[:notify]
        Message.create(
          from_id: current_user.id,
          to_id: change.user_id,
          kind: MessageType::Notification,
          body: "Ваша [user_change=#{change.id}]правка[/user_change] для [#{change.item.class.name.downcase}]#{change.item.id}[/#{change.item.class.name.downcase}] отклонена."
        ) unless change.user_id == current_user.id
      end

      redirect_to_back_or_to moderation_user_changes_url
    else
      render json: change.errors, status: :unprocessable_entity
    end
  end

  # забрать аниме на перевод
  def get_anime_lock
    unless Group.find(Group::TranslatorsID).joined?(current_user)
      render json: ['Только участники группы переводов могут забирать аниме на перевод'], status: :unprocessable_entity
      return
    end
    anime = Anime.find(params[:anime_id])

    can_be_locked = UserChange.where(status: [UserChangeStatus::Locked])
      .where(item_id: anime, model: Anime.name, column: 'description')
      .empty?
    raise Forbidden unless can_be_locked

    if UserChange.where(status: UserChangeStatus::Locked, user_id: current_user.id).count > 4
      render json: ['Нельзя забрать на перевод более четырёх аниме'], status: :unprocessable_entity
    else
      UserChange.create!(user_id: current_user.id, item_id: anime.id, model: Anime.name, status: UserChangeStatus::Locked, column: 'description')
      render json: {
        success: true,
        notice: '%s забрано на перевод' % anime.name,
        html: render_to_string(partial: 'translation/lock', locals: {
          anime: anime.reload,
          changes: TranslationController.pending_animes,
          locks: TranslationController.locked_animes
        }, formats: :html)
      }
    end
  end

  # отменить право на перевод аниме
  def release_anime_lock
    anime = Anime.find(params[:anime_id])

    lock = UserChange.where(status: UserChangeStatus::Locked, user_id: current_user.id, item_id: anime, model: Anime.name).first
    can_be_unlocked = current_user.admin? || lock != nil
    raise Forbidden unless can_be_unlocked
    lock.destroy

    render json: {
      success: true,
      notice: 'Перевод %s отменен' % anime.name,
      html: render_to_string(partial: 'translation/lock', locals: {
        anime: anime,
        changes: TranslationController.pending_animes,
        locks: TranslationController.locked_animes
      }, formats: :html)
    }
  end

private
  def user_change_params
    params
      .require(:change)
      .permit(:model, :column, :item_id, :value, :source, :action)
  end
end
